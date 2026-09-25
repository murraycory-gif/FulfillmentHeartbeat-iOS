#!/bin/sh
# Build / publish the Heartbeat pack testers open.
# The iPad never parses Excel. It only reads current.sqlite + pulse-cards.json.
#
# First time (creates the pack from a loaded iPad):
#   DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./build-pack.sh
#
# Daily workbook upload (private R2, then the cook). This script does not
# send the xlsx anywhere:
#   ./ingest-heartbeat.sh "/path/Heartbeat Daily Report.xlsx"
#
# Pack from the iPad, when you still publish that way:
#   R2_ACCESS_KEY_ID=… R2_SECRET_ACCESS_KEY=… R2_ACCOUNT_ID=… R2_BUCKET=heartbeat-packs \
#   DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./build-pack.sh
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
UDID="${DEVICE_UDID:-}"
XLSX="${1:-}"

upload_pack() {
  NAME="$1"
  FILE="$2"
  TYPE="$3"
  chmod +x scripts/publish-r2.sh
  ./scripts/publish-r2.sh "$FILE" "$NAME" "$TYPE"
}

if [ -n "$XLSX" ]; then
  if [ ! -f "$XLSX" ]; then
    echo "File not found: $XLSX"
    exit 1
  fi
  echo "This script does not archive the workbook."
  echo "Upload it with: ./ingest-heartbeat.sh \"$XLSX\""
fi

if [ -z "$UDID" ]; then
  echo "Set DEVICE_UDID and run again to publish current.sqlite from the iPad."
  echo "Open Heartbeat on the iPad once so it can write the pack, then:"
  echo "  DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./build-pack.sh"
  exit 0
fi

LOCAL="/tmp/heartbeat-current.sqlite"
CARDS="/tmp/pulse-cards.json"
echo "Copying pack off the iPad…"
rm -f "$LOCAL" "$CARDS"
xcrun devicectl device copy from \
  --device "$UDID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "Documents/Pulse/heartbeat.sqlite" \
  --destination "$LOCAL"

BYTES=$(wc -c < "$LOCAL" | tr -d ' ')
if [ "$BYTES" -lt 50000 ]; then
  echo "Pack is too small ($BYTES bytes). Open Heartbeat on the iPad first."
  exit 1
fi

echo "Publishing current.sqlite ($BYTES bytes) to R2…"
upload_pack "current.sqlite" "$LOCAL" "application/octet-stream"

if xcrun devicectl device copy from \
  --device "$UDID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "Documents/Pulse/pulse-cards.json" \
  --destination "$CARDS" 2>/dev/null; then
  echo "Publishing pulse-cards.json to R2…"
  upload_pack "pulse-cards.json" "$CARDS" "application/json" || true
fi

echo "Done. Testers open Heartbeat — they do not pick a file."
echo "Download: https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite"
