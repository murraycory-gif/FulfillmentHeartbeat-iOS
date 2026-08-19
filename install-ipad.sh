#!/bin/sh
# Build, install, and open Fulfillment Heartbeat on a connected iPad
# without Xcode's debugger. Use this when Run fails with CoreDevice /
# Mercury "connection was invalidated".
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
WORKSPACE="FulfillmentHeartbeat.xcworkspace"
SCHEME="FulfillmentHeartbeat"

echo "Unlock the iPad and keep it on this screen."
echo "Building for device..."

DERIVED="${TMPDIR:-/tmp}/HeartbeatDeviceBuild"
rm -rf "$DERIVED"

xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  build

APP=$(find "$DERIVED/Build/Products" -name 'FulfillmentHeartbeat.app' -print -quit)
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "Build finished but the .app was not found."
  exit 1
fi

UDID="${DEVICE_UDID:-}"
if [ -z "$UDID" ]; then
  JSON="${TMPDIR:-/tmp}/heartbeat-devices.json"
  if xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1; then
    UDID=$(python3 - "$JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
devices = data.get("result", {}).get("devices", data if isinstance(data, list) else [])
for device in devices:
    ident = device.get("identifier") or device.get("udid") or ""
    name = (device.get("deviceProperties") or {}).get("name") or device.get("name") or ""
    hardware = (device.get("hardwareProperties") or {})
    platform = str(hardware.get("platform") or device.get("platform") or "")
    conn = device.get("connectionProperties") or {}
    transport = str(conn.get("transportType") or conn.get("pairingState") or "")
    if "iPad" in name or "iPad" in str(hardware.get("marketingName") or "") or "iOS" in platform:
        print(ident)
        break
PY
)
  fi
fi

if [ -z "${UDID:-}" ]; then
  UDID=$(xcrun xctrace list devices 2>/dev/null | awk -F'[()]' '/iPad/ && !/Simulator/ { print $2; exit }' || true)
fi

if [ -z "${UDID:-}" ]; then
  echo "No iPad found. Plug it in, unlock it, tap Trust, then run again."
  echo "Or: DEVICE_UDID=00008103-000960E61E30801E ./install-ipad.sh"
  exit 1
fi

echo "Installing on $UDID ..."
xcrun devicectl device install app --device "$UDID" "$APP"

echo "Opening Heartbeat..."
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || true

echo ""
echo "If the debugger is not attached, that is expected."
echo "Tap Heartbeat on the iPad if it did not come to the front."
