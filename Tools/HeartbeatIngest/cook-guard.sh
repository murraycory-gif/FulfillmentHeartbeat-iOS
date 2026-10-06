#!/bin/bash
# Mac cook guard. Classifies paths before cook-local.sh cooks.
#
# Pinned cook paths are refused when they are dirty. The cook does not run:
#   web/scripts/extract_web_pack.py
#   Tools/HeartbeatIngest/cook-local.sh
#   Tools/HeartbeatIngest/          every file under this directory
#   web/check_pack.mjs
#   web/functions/pack-store.js     the middleware schema and required-key
#                                   list, guardHome:
#                                     schemaVersion
#                                     cookSha
#                                     laborMarket (no weight field; UPLH +
#                                       Wage + AIV = Target vs Actual)
#                                     regionTables
#                                     summaries
#                                     companyTiles
#                                     filters.stores
#
# Tools/HeartbeatIngest/publish-web.sh is flagged for review. That is not an
# auto-refuse. The cook still runs so a person can read the diff.
#
# Any other path is refused.
#
# Usage: cook-guard.sh [path...]
# Prints one line: cook, review, or refuse.
# Exit 0 for cook or review. Exit 1 for refuse.
# No paths means cook.

set -euo pipefail

classify_one() {
  local path="${1#./}"
  if [[ "$path" == "Tools/HeartbeatIngest/publish-web.sh" ]]; then
    echo review
    return
  fi
  if [[ "$path" == "web/scripts/extract_web_pack.py" \
    || "$path" == "Tools/HeartbeatIngest/cook-local.sh" \
    || "$path" == Tools/HeartbeatIngest/* \
    || "$path" == "web/check_pack.mjs" \
    || "$path" == "web/functions/pack-store.js" ]]; then
    echo refuse
    return
  fi
  echo refuse
}

on_cook_path() {
  local path="${1#./}"
  [[ "$path" == "Tools/HeartbeatIngest/publish-web.sh" \
    || "$path" == "web/scripts/extract_web_pack.py" \
    || "$path" == "Tools/HeartbeatIngest/cook-local.sh" \
    || "$path" == Tools/HeartbeatIngest/* \
    || "$path" == "web/check_pack.mjs" \
    || "$path" == "web/functions/pack-store.js" ]]
}

porcelain_path() {
  local rest="${1:3}"
  if [[ "$rest" == *" -> "* ]]; then
    printf '%s' "${rest##* -> }"
  else
    printf '%s' "$rest"
  fi
}

# --decide-publish AHEAD reads porcelain lines on stdin.
# --publish checks this repo: env overrides, unpushed commits, and dirty cook paths.
decide_publish() {
  local ahead="$1"
  local line path
  if [[ "$ahead" -gt 0 ]]; then
    echo "refuse"
    echo "cook guard: refusing unpushed commits" >&2
    return 1
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    path="$(porcelain_path "$line")"
    if ! on_cook_path "$path"; then
      continue
    fi
    echo "refuse"
    if [[ "$path" == "Tools/HeartbeatIngest/publish-web.sh" ]]; then
      echo "cook guard: refusing a dirty publish-web.sh" >&2
    elif [[ "$line" == "?? "* ]]; then
      echo "cook guard: refusing an untracked cook path" >&2
    else
      echo "cook guard: refusing a dirty cook path" >&2
    fi
    return 1
  done
  echo "cook"
  return 0
}

if [[ "${1:-}" == "--decide-publish" ]]; then
  decide_publish "${2:-0}"
  exit
fi

if [[ "${1:-}" == "--publish" ]]; then
  if [[ -n "${HEARTBEAT_SKIP_GIT_CHECK:-}" || -n "${HEARTBEAT_SKIP_PACK_CHECK:-}" ]]; then
    echo "refuse"
    echo "cook guard: refusing an env override" >&2
    exit 1
  fi
  root="$(cd "$(dirname "$0")/../.." && pwd)"
  branch="$(git -C "$root" rev-parse --abbrev-ref HEAD)"
  ahead=0
  if git -C "$root" rev-parse --verify --quiet "origin/${branch}" >/dev/null; then
    ahead="$(git -C "$root" rev-list --count "origin/${branch}..HEAD")"
  else
    ahead=1
  fi
  git -C "$root" status --porcelain | decide_publish "$ahead"
  exit
fi

result="cook"
for path in "$@"; do
  one="$(classify_one "$path")"
  if [[ "$one" == "refuse" ]]; then
    result="refuse"
  elif [[ "$one" == "review" && "$result" != "refuse" ]]; then
    result="review"
  fi
done

echo "$result"
if [[ "$result" == "review" ]]; then
  echo "cook guard: publish-web.sh is flagged for review" >&2
fi
if [[ "$result" == "refuse" ]]; then
  echo "cook guard: refusing a dirty cook path" >&2
  exit 1
fi
