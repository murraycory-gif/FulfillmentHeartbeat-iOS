#!/bin/bash
# com.exclusivegroup.heartbeat-autoingest
# Watches iCloud Heartbeat_Reports. A new Heartbeat Daily Report or
# Schedule Review Summary workbook cooks into current.sqlite, then
# publish-web.sh deploys ONLY to Cloudflare Pages fulfillment-heartbeat-web.
#
# Unchanged files are a no-op. A cook or deploy error does not publish.
# The API token is read from the environment or
# ~/.config/heartbeat/cloudflare-api-token. It is never printed.
#
#   ./Tools/HeartbeatIngest/cook-local.sh
#   ./Tools/HeartbeatIngest/cook-local.sh --install

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICLOUD="${HEARTBEAT_ICLOUD_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Heartbeat_Reports}"
MARKERS="${HEARTBEAT_COOK_MARKERS:-$HOME/Library/Application Support/Heartbeat/cook-markers}"
OUT="${HEARTBEAT_COOK_OUT:-$HOME/Library/Application Support/Heartbeat}"
SETTLE="${HEARTBEAT_SETTLE_SECONDS:-3}"
SQLITE="$OUT/current.sqlite"
mkdir -p "$MARKERS" "$OUT"

install_agent() {
  local src="$ROOT/Tools/HeartbeatIngest/cook-local.sh"
  local template="$ROOT/Tools/HeartbeatIngest/com.exclusivegroup.heartbeat-autoingest.plist"
  local dest="$HOME/Library/LaunchAgents/com.exclusivegroup.heartbeat-autoingest.plist"
  local watch="$ICLOUD"
  mkdir -p "$HOME/Library/LaunchAgents" "$watch" "$OUT"
  sed \
    -e "s#__COOK__#${src}#g" \
    -e "s#__WATCH__#${watch}#g" \
    -e "s#__LOG__#${OUT}#g" \
    "$template" > "$dest"
  local domain="gui/$(id -u)"
  launchctl bootout "$domain/com.exclusivegroup.heartbeat-autoingest" 2>/dev/null || true
  launchctl bootstrap "$domain" "$dest" || launchctl load -w "$dest"
  echo "Installed $dest"
  echo "Watching $watch"
}

newest_file() {
  python3 - "$1" "$2" << 'PY'
import os, sys
folder, kind = sys.argv[1], sys.argv[2]
if not os.path.isdir(folder):
    sys.exit(0)
found = []
for name in os.listdir(folder):
    if name.startswith("~$") or name.startswith(".") or name.endswith(".icloud"):
        continue
    if not name.lower().endswith(".xlsx"):
        continue
    path = os.path.join(folder, name)
    if not os.path.isfile(path):
        continue
    folded = name.replace("_", " ").lower()
    if kind == "schedule":
        if "schedule review" in folded and ("summary" in folded or folded.startswith("schedule review week ")):
            found.append(path)
    else:
        if folded.startswith("heartbeat") and "schedule" not in folded:
            found.append(path)
if not found:
    sys.exit(0)
found.sort(key=lambda path: os.path.getmtime(path), reverse=True)
print(found[0])
PY
}

mtime_of() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"
}

bytes_of() {
  stat -c %s "$1" 2>/dev/null || stat -f %z "$1"
}

file_stamp() {
  local file="$1"
  printf '%s:%s:%s\n' "$(mtime_of "$file")" "$(bytes_of "$file")" "$(basename "$file")"
}

marker_matches() {
  local marker="$1" file="$2"
  [[ -f "$marker" && -f "$file" ]] || return 1
  local have
  have="$(cat "$marker")"
  [[ "$have" == "$(file_stamp "$file")" ]]
}

write_marker() {
  local marker="$1" file="$2"
  file_stamp "$file" > "$marker"
}

file_settling() {
  local file="$1"
  local stamp now age
  stamp="$(mtime_of "$file")"
  now="$(date +%s)"
  age=$(( now - stamp ))
  [[ "$age" -lt "$SETTLE" ]]
}

schedule_rows() {
  if [[ ! -f "$SQLITE" ]]; then
    echo 0
    return
  fi
  python3 - "$SQLITE" << 'PY'
import sqlite3, sys
try:
    con = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    count = con.execute("SELECT COUNT(*) FROM schedule_store").fetchone()[0]
except Exception:
    count = 0
print(count)
PY
}

published_at() {
  python3 - "$SQLITE" << 'PY'
import json, sqlite3, sys
con = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
raw = con.execute("SELECT json FROM dash_chrome WHERE id = 1").fetchone()
if not raw:
    raise SystemExit(1)
chrome = json.loads(raw[0])
stamp = chrome.get("publishedAt") or ""
if not stamp:
    raise SystemExit(1)
print(stamp)
PY
}

cook_daily() {
  local file="$1"
  local bin="${HEARTBEAT_INGEST_BIN:-$ROOT/Tools/HeartbeatIngest/.build/release/HeartbeatIngest}"
  if [[ ! -x "$bin" ]]; then
    echo "heartbeat cook failed: ingest binary not built ($bin)" >&2
    return 1
  fi
  local bytes
  bytes="$(bytes_of "$file")"
  if (( bytes < 1000000 )); then
    echo "heartbeat cook failed: $(basename "$file") is ${bytes} bytes" >&2
    return 1
  fi
  echo "cooking daily $(basename "$file")"
  HEARTBEAT_SKIP_SEAT_PACKS=1 "$bin" "$file" "$SQLITE"
}

cook_schedule_file() {
  local file="$1"
  if [[ ! -f "$SQLITE" ]]; then
    echo "schedule cook failed: current.sqlite is missing" >&2
    return 1
  fi
  echo "cooking schedule $(basename "$file")"
  if [[ -n "${HEARTBEAT_SCHEDULE_CMD:-}" ]]; then
    HEARTBEAT_SCHEDULE_FILE="$file" HEARTBEAT_SCHEDULE_SQLITE="$SQLITE" bash -lc "$HEARTBEAT_SCHEDULE_CMD"
    return $?
  fi
  python3 "$ROOT/Tools/ScheduleCheck/cook_schedule.py" \
    "$file" \
    "$OUT/schedule-check.json" \
    --sqlite "$SQLITE" \
    --publish-sheet
}

deploy_site() {
  local daily="${1:-}"
  if [[ -n "${HEARTBEAT_DEPLOY_CMD:-}" ]]; then
    bash -lc "$HEARTBEAT_DEPLOY_CMD"
    return $?
  fi
  if [[ -n "$daily" && -f "$daily" ]]; then
    HEARTBEAT_DAILY_XLSX="$daily" bash "$ROOT/Tools/HeartbeatIngest/publish-web.sh" "$SQLITE"
    return $?
  fi
  bash "$ROOT/Tools/HeartbeatIngest/publish-web.sh" "$SQLITE"
}

run_pipeline() {
  local daily sched
  daily="$(newest_file "$ICLOUD" heartbeat || true)"
  sched="$(newest_file "$ICLOUD" schedule || true)"
  if [[ -z "${daily:-}" ]]; then
    echo "heartbeat cook failed: no Heartbeat Daily Report workbook in $ICLOUD" >&2
    return 1
  fi
  if [[ -z "${sched:-}" ]]; then
    echo "schedule cook failed: no Schedule Review Summary workbook in $ICLOUD" >&2
    return 1
  fi
  if file_settling "$daily" || file_settling "$sched"; then
    echo "workbook still settling; will cook on the next run"
    return 0
  fi

  local daily_marker="$MARKERS/heartbeat.marker"
  local sched_marker="$MARKERS/schedule.marker"
  local deploy_marker="$MARKERS/deploy.marker"
  local need_daily=0 need_sched=0 rows=0
  if ! marker_matches "$daily_marker" "$daily" || [[ ! -f "$SQLITE" ]]; then
    need_daily=1
  fi
  rows="$(schedule_rows)"
  if ! marker_matches "$sched_marker" "$sched" || [[ "$need_daily" -eq 1 ]] || [[ "${rows:-0}" -eq 0 ]]; then
    need_sched=1
  fi

  if [[ "$need_daily" -eq 0 && "$need_sched" -eq 0 ]]; then
    local stamp deployed
    stamp="$(published_at)" || return 1
    deployed="$(cat "$deploy_marker" 2>/dev/null || true)"
    if [[ "$deployed" == "$stamp" ]]; then
      echo "unchanged $(basename "$daily") $(basename "$sched") publishedAt=$stamp"
      return 0
    fi
    echo "redeploying cooked pack publishedAt=$stamp"
  else
    if [[ "$need_daily" -eq 1 ]]; then
      cook_daily "$daily" || return 1
      write_marker "$daily_marker" "$daily"
    fi
    if [[ "$need_sched" -eq 1 ]]; then
      cook_schedule_file "$sched" || return 1
      write_marker "$sched_marker" "$sched"
    fi
  fi

  deploy_site "$daily" || return 1
  published_at > "$deploy_marker"
  echo "deployed $(cat "$deploy_marker")"
  return 0
}

if [[ "${1:-}" == "--install" ]]; then
  install_agent
  exit 0
fi

LOCK="$OUT/cook.lockdir"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "cook already running"
  exit 0
fi
trap 'rmdir "$LOCK"' EXIT

set +e
run_pipeline
status=$?
set -e
exit "$status"
