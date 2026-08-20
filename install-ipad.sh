#!/bin/sh
# Build, install, and open Fulfillment Heartbeat on a connected iPad
# without Xcode's debugger.
# SKIP_BUILD=1 reuses the last .app so a dropped cable is a 10-second retry.
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
WORKSPACE="FulfillmentHeartbeat.xcworkspace"
SCHEME="FulfillmentHeartbeat"
DERIVED="${TMPDIR:-/tmp}/HeartbeatDeviceBuild"

echo "Unlock the iPad, keep it awake, and leave it on the Home Screen."

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "Building for device..."
  rm -rf "$DERIVED"
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    build
fi

APP=$(find "$DERIVED/Build/Products" -name 'FulfillmentHeartbeat.app' -print -quit 2>/dev/null || true)
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "No built app found. Run without SKIP_BUILD=1 first."
  exit 1
fi

wait_for_ipad() {
  tries=0
  while [ "$tries" -lt 12 ]; do
    JSON="${TMPDIR:-/tmp}/heartbeat-devices.json"
    if xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1; then
      FOUND=$(python3 - "$JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
devices = data.get("result", {}).get("devices", []) or data.get("devices", [])
for device in devices:
    hardware = device.get("hardwareProperties") or {}
    props = device.get("deviceProperties") or {}
    conn = device.get("connectionProperties") or {}
    name = props.get("name") or device.get("name") or ""
    marketing = str(hardware.get("marketingName") or "")
    ident = device.get("identifier") or hardware.get("udid") or ""
    tunnel = str(conn.get("tunnelState") or "").lower()
    transport = str(conn.get("transportType") or "").lower()
    pairing = str(conn.get("pairingState") or "").lower()
    is_ipad = "iPad" in name or "iPad" in marketing or str(hardware.get("deviceType") or "").startswith("iPad")
    if not is_ipad:
        continue
    available = tunnel in ("connected", "ready") or transport in ("wired", "localnetwork", "wifi")
    if available and pairing in ("paired", "pairable", ""):
        print(ident)
        print(f"Found {name} {ident}", file=sys.stderr)
        sys.exit(0)
sys.exit(1)
PY
) && { echo "$FOUND"; return 0; }
    fi
    tries=$((tries + 1))
    echo "Waiting for the iPad… unplug, unlock, plug back in ($tries/12)"
    sleep 3
  done
  return 1
}

UDID="${DEVICE_UDID:-}"
if [ -z "$UDID" ]; then
  UDID=$(wait_for_ipad || true)
fi

if [ -z "${UDID:-}" ]; then
  echo "No available iPad. Unlock it, unplug the cable, plug it back in, tap Trust."
  xcrun devicectl list devices || true
  exit 1
fi

echo "Installing on $UDID ..."
if ! xcrun devicectl device install app --device "$UDID" "$APP"; then
  echo ""
  echo "Install failed. Connected devices:"
  xcrun devicectl list devices || true
  exit 1
fi

echo "Opening Heartbeat..."
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || true

echo ""
echo "Tap the Heartbeat icon if it did not come forward."
echo "Top-right stamp should match FulfillmentHeartbeat/BuildStamp.swift (currently HB-0820.44)."
