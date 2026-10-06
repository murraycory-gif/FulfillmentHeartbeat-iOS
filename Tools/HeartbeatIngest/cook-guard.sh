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
