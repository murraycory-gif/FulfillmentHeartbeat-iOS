#!/bin/sh
# Build and open Heartbeat on this Mac (Mac Catalyst). Does not delete the app.
# Does not pull main. Tip: cursor/command-center-8b-3389 @ b960f08 (HB-0828.400 / 726).
#   ./install-mac.sh
#   CONFIGURATION=Release ./install-mac.sh
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
WORKSPACE="FulfillmentHeartbeat.xcworkspace"
SCHEME="FulfillmentHeartbeat"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED="${TMPDIR:-/tmp}/HeartbeatMacCatalystBuild"
DEST="${BUILD_DESTINATION:-platform=macOS,variant=Mac Catalyst}"

stamp_id() {
  python3 - <<'PY'
import re, pathlib
text = pathlib.Path("FulfillmentHeartbeat/BuildStamp.swift").read_text()
match = re.search(r'id = "([^"]+)"', text)
print(match.group(1) if match else "unknown")
PY
}

if [ "${SKIP_PULL:-0}" != "1" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Fetching tip cursor/command-center-8b-3389 (does not merge main)..."
  git fetch origin cursor/command-center-8b-3389
  git checkout cursor/command-center-8b-3389
  git reset --hard origin/cursor/command-center-8b-3389
fi

STAMP="$(stamp_id)"
SHA="$(git rev-parse --short HEAD)"
echo "Source stamp: $STAMP  SHA $SHA  $CONFIGURATION Catalyst"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  rm -rf "$DERIVED"
  LOG="${TMPDIR:-/tmp}/heartbeat-mac-build.log"
  echo "xcodebuild destination: $DEST"
  if ! xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DEST" \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    build > "$LOG" 2>&1; then
    echo ""
    echo "----- Swift errors -----"
    grep -E "error:|fatal error:|Unable to find a destination" "$LOG" | sed 's/^[[:space:]]*//' || tail -80 "$LOG"
    echo "----- end errors -----"
    echo "Full log: $LOG"
    exit 1
  fi
fi

APP=$(find "$DERIVED/Build/Products" -name 'FulfillmentHeartbeat.app' -print -quit 2>/dev/null || true)
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "No built Mac Catalyst app. Run without SKIP_BUILD=1 first."
  exit 1
fi

echo "Opening $APP (replaces the running Mac build; does not delete Documents/Pulse)."
open -n "$APP" --args || open "$APP"
echo ""
echo "Sidebar stamp must read $STAMP  1.0 (726). SHA $SHA."
echo "If Sales is still ~\$49M / Wednesday, quit Heartbeat from the Dock and reopen — do not delete the app."
echo "Bundle $BUNDLE_ID"
