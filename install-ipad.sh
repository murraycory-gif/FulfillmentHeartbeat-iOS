#!/bin/sh
# Build, install, and open Fulfillment Heartbeat on a connected iPad
# without Xcode's debugger. Use this when Run fails with CoreDevice /
# Mercury "connection was invalidated".
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
WORKSPACE="FulfillmentHeartbeat.xcworkspace"
SCHEME="FulfillmentHeartbeat"

echo "Unlock the iPad, keep it awake, and leave it on the Home Screen."
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

pick_udid() {
  JSON="${TMPDIR:-/tmp}/heartbeat-devices.json"
  if ! xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1; then
    return 1
  fi
  python3 - "$JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
devices = data.get("result", {}).get("devices", [])
if not devices and isinstance(data, dict):
    devices = data.get("devices", [])

picked = []
for device in devices:
    hardware = device.get("hardwareProperties") or {}
    props = device.get("deviceProperties") or {}
    conn = device.get("connectionProperties") or {}
    name = props.get("name") or device.get("name") or ""
    marketing = str(hardware.get("marketingName") or "")
    platform = str(hardware.get("platform") or device.get("platform") or "")
    udid = hardware.get("udid") or device.get("udid") or ""
    ident = device.get("identifier") or ""
    transport = str(conn.get("transportType") or "")
    tunnel = str(conn.get("tunnelState") or "")
    pairing = str(conn.get("pairingState") or "")
    sim = bool(hardware.get("internalName") == "simulator" or "Simulator" in name or "simulator" in platform.lower())
    if sim:
        continue
    is_ipad = "iPad" in name or "iPad" in marketing or str(hardware.get("deviceType") or "").startswith("iPad")
    if not is_ipad and "iOS" not in platform and "iPadOS" not in platform:
        continue
    connected = tunnel.lower() in ("connected", "ready") or transport.lower() in ("wired", "localnetwork", "wifi")
    score = 0
    if is_ipad:
        score += 10
    if connected:
        score += 5
    if pairing.lower() == "paired":
        score += 2
    if transport.lower() == "wired":
        score += 3
    # Prefer the hardware UDID (00008103-...) over pairing UUIDs / ecid_ ids.
    chosen = ""
    for candidate in (udid, ident):
        text = str(candidate)
        if not text or text.startswith("ecid_"):
            continue
        if text.count("-") == 4 and len(text) == 36 and not text.startswith("0000"):
            # pairing UUID — keep as last resort
            if not chosen:
                chosen = text
            continue
        chosen = text
        break
    if chosen:
        picked.append((score, chosen, name or marketing, transport or tunnel))

picked.sort(reverse=True)
if picked:
    score, udid, name, how = picked[0]
    print(udid)
    print(f"Using {name} ({how or 'connected'}) {udid}", file=sys.stderr)
    sys.exit(0)
sys.exit(1)
PY
}

UDID="${DEVICE_UDID:-}"
if [ -z "$UDID" ]; then
  UDID=$(pick_udid || true)
fi

if [ -z "${UDID:-}" ]; then
  UDID=$(xcrun xctrace list devices 2>/dev/null | awk -F'[()]' '/iPad/ && !/Simulator/ { gsub(/ /, "", $2); if ($2 ~ /^[0-9A-Fa-f-]+$/) { print $2; exit } }' || true)
fi

if [ -z "${UDID:-}" ]; then
  echo ""
  echo "No connected iPad found."
  echo "Plug it in, unlock it, tap Trust if asked, then run:"
  echo "  xcrun devicectl list devices"
  echo "  DEVICE_UDID=00008103-000960E61E30801E ./install-ipad.sh"
  exit 1
fi

echo "Installing on $UDID ..."
if ! xcrun devicectl device install app --device "$UDID" "$APP"; then
  echo ""
  echo "Install failed. Connected devices:"
  xcrun devicectl list devices || true
  echo ""
  echo "If your iPad is listed, copy its Identifier and run:"
  echo "  DEVICE_UDID=PASTE_ID_HERE ./install-ipad.sh"
  exit 1
fi

echo "Opening Heartbeat..."
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || true

echo ""
echo "If it did not come to the front, tap the Heartbeat icon on the iPad."
echo "That is the app. Xcode does not need to stay attached."
