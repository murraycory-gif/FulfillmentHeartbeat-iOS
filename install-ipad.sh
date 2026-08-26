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

wait_for_ipad() {
  want="${1:-}"
  tries=0
  while [ "$tries" -lt 20 ]; do
    JSON="${TMPDIR:-/tmp}/heartbeat-devices.json"
    if xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1; then
      FOUND=$(WANT="$want" python3 - "$JSON" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1]))
devices = data.get("result", {}).get("devices", []) or data.get("devices", [])
want = os.environ.get("WANT", "").strip().lower()
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
    if want and ident.lower() != want:
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
    echo "Waiting for the iPad… unlock it, unplug, plug back in, tap Trust ($tries/20)" >&2
    sleep 3
  done
  return 1
}

UDID="${DEVICE_UDID:-}"
if [ -n "$UDID" ]; then
  echo "Looking for iPad $UDID ..."
  READY=$(wait_for_ipad "$UDID" || true)
  if [ -z "${READY:-}" ]; then
    echo "iPad $UDID is still unavailable."
    xcrun devicectl list devices || true
    echo ""
    echo "Unlock the iPad, leave it on the Home Screen, unplug the cable, plug it back in, tap Trust, then rerun."
    exit 1
  fi
  UDID="$READY"
else
  UDID=$(wait_for_ipad || true)
fi

if [ -z "${UDID:-}" ]; then
  echo "No available iPad. Unlock it, unplug the cable, plug it back in, tap Trust."
  xcrun devicectl list devices || true
  exit 1
fi

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "Building for this iPad ($UDID)..."
  rm -rf "$DERIVED"
  LOG="${TMPDIR:-/tmp}/heartbeat-build.log"
  if ! xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build > "$LOG" 2>&1; then
    echo ""
    echo "----- Swift errors -----"
    grep -E "error:|fatal error:" "$LOG" | sed 's/^[[:space:]]*//' || tail -80 "$LOG"
    echo "----- end errors -----"
    echo "Full log: $LOG"
    exit 1
  fi
fi

APP=$(find "$DERIVED/Build/Products" -name 'FulfillmentHeartbeat.app' -print -quit 2>/dev/null || true)
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "No built app found. Run without SKIP_BUILD=1 first."
  exit 1
fi

echo "Installing on $UDID ..."
if ! xcrun devicectl device install app --device "$UDID" "$APP"; then
  echo ""
  echo "Install failed. Connected devices:"
  xcrun devicectl list devices || true
  echo ""
  echo "If you see provisioning / integrity errors:"
  echo "  1. Delete Heartbeat from the iPad Home Screen."
  echo "  2. Settings → General → VPN & Device Management → tap your Apple ID → Trust."
  echo "  3. Unlock the iPad, leave it on the Home Screen."
  echo "  4. Rerun (do not use SKIP_BUILD=1):"
  echo "       DEVICE_UDID=$UDID ./install-ipad.sh"
  exit 1
fi

echo "Opening Heartbeat..."
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || true

echo ""
echo "Tap the Heartbeat icon if it did not come forward."
echo "Top-right stamp should match FulfillmentHeartbeat/BuildStamp.swift (currently HB-0826.1)."
