#!/bin/bash
# com.exclusivegroup.heartbeat-autoingest
# Watches the iCloud Heartbeat_Reports folder. Heartbeat workbooks and
# Schedule Review workbooks cook in separate subshells. One failure never
# stops the other. Schedule publishes schedule-check.json next to the
# Heartbeat pack on R2 only when R2 credentials are already in the environment.
# This script does not create Cloudflare resources.
#
#   ./Tools/HeartbeatIngest/cook-local.sh
#   ./Tools/HeartbeatIngest/cook-local.sh --install

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICLOUD="${HEARTBEAT_ICLOUD_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Heartbeat_Reports}"
MARKERS="${HEARTBEAT_COOK_MARKERS:-$HOME/Library/Application Support/Heartbeat/cook-markers}"
OUT="${HEARTBEAT_COOK_OUT:-$HOME/Library/Application Support/Heartbeat}"
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
  python3 - "$1" "$2" <<'PY'
import fnmatch, os, sys
folder, kind = sys.argv[1], sys.argv[2]
if not os.path.isdir(folder):
    sys.exit(0)
found = []
for name in os.listdir(folder):
    if name.startswith("~$") or not name.lower().endswith(".xlsx"):
        continue
    path = os.path.join(folder, name)
    if not os.path.isfile(path):
        continue
    if kind == "schedule":
        if fnmatch.fnmatch(name, "Schedule Review Week *.xlsx"):
            found.append(path)
    else:
        if name.startswith("Heartbeat") and "Schedule Review" not in name:
            found.append(path)
if not found:
    sys.exit(0)
found.sort(key=lambda path: os.path.getmtime(path), reverse=True)
print(found[0])
PY
}

marker_matches() {
  local marker="$1" file="$2"
  [[ -f "$marker" && -f "$file" ]] || return 1
  local stamp size have
  stamp="$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file")"
  size="$(stat -f %z "$file" 2>/dev/null || stat -c %s "$file")"
  have="$(cat "$marker")"
  [[ "$have" == "$stamp:$size:$(basename "$file")" ]]
}

write_marker() {
  local marker="$1" file="$2"
  local stamp size
  stamp="$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file")"
  size="$(stat -f %z "$file" 2>/dev/null || stat -c %s "$file")"
  printf '%s\n' "$stamp:$size:$(basename "$file")" > "$marker"
}

publish_schedule() {
  local file="$1"
  if [[ -z "${R2_ACCESS_KEY_ID:-}" || -z "${R2_SECRET_ACCESS_KEY:-}" || -z "${R2_BUCKET:-}" || -z "${R2_ENDPOINT:-}" ]]; then
    echo "schedule publish skipped: no r2 key"
    return 0
  fi
  AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    aws s3 cp "$file" "s3://${R2_BUCKET}/schedule-check.json" \
      --endpoint-url "$R2_ENDPOINT" --only-show-errors
}

cook_heartbeat() {
  set -euo pipefail
  local file bin marker
  file="$(newest_file "$ICLOUD" heartbeat || true)"
  if [[ -z "${file:-}" ]]; then
    echo "heartbeat cook skipped: no Heartbeat workbook"
    return 0
  fi
  marker="$MARKERS/heartbeat.marker"
  if marker_matches "$marker" "$file"; then
    echo "heartbeat unchanged $(basename "$file")"
    return 0
  fi
  bin="$ROOT/Tools/HeartbeatIngest/.build/release/HeartbeatIngest"
  if [[ ! -x "$bin" ]]; then
    echo "heartbeat cook skipped: ingest binary not built"
    return 0
  fi
  "$bin" "$file" "$OUT/current.sqlite"
  write_marker "$marker" "$file"
  echo "heartbeat cooked $(basename "$file")"
}

cook_schedule() {
  set -euo pipefail
  local file marker
  file="$(newest_file "$ICLOUD" schedule || true)"
  if [[ -z "${file:-}" ]]; then
    echo "schedule cook skipped: no Schedule Review Week workbook"
    return 0
  fi
  marker="$MARKERS/schedule.marker"
  if marker_matches "$marker" "$file"; then
    echo "schedule unchanged $(basename "$file")"
    return 0
  fi
  python3 "$ROOT/Tools/ScheduleCheck/cook_schedule.py" "$file" "$OUT/schedule-check.json"
  write_marker "$marker" "$file"
  publish_schedule "$OUT/schedule-check.json"
  echo "schedule cooked $(basename "$file")"
}

if [[ "${1:-}" == "--install" ]]; then
  install_agent
  exit 0
fi

set +e
( cook_heartbeat )
heartbeat_status=$?
( cook_schedule )
schedule_status=$?
if [[ "$heartbeat_status" -ne 0 ]]; then
  echo "heartbeat cook failed (schedule cook is independent)"
fi
if [[ "$schedule_status" -ne 0 ]]; then
  echo "schedule cook failed (heartbeat cook is independent)"
fi
exit 0
