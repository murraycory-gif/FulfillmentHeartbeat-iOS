#!/bin/sh
# Publish the on-device SQLite pack to R2 so testers never parse Excel.
# Usage:
#   R2_ACCESS_KEY_ID=… R2_SECRET_ACCESS_KEY=… R2_ACCOUNT_ID=… R2_BUCKET=heartbeat-packs \
#   DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./publish-pack.sh
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
UDID="${DEVICE_UDID:-}"
OBJECT="current.sqlite"
LOCAL="/tmp/heartbeat-current.sqlite"

if [ -z "$UDID" ]; then
  echo "Set DEVICE_UDID to the iPad UDID."
  exit 1
fi

echo "Copying heartbeat.sqlite off the iPad…"
rm -f "$LOCAL"
if ! xcrun devicectl device copy from \
  --device "$UDID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "Documents/Pulse/heartbeat.sqlite" \
  --destination "$LOCAL"; then
  echo "Could not copy Documents/Pulse/heartbeat.sqlite from the iPad."
  echo "Open Heartbeat → Upload the Daily Report once, wait until Labor and Picker show, then rerun."
  exit 1
fi

BYTES=$(wc -c < "$LOCAL" | tr -d ' ')
if [ "$BYTES" -lt 50000 ]; then
  echo "Pack is too small ($BYTES bytes). Load the workbook on the iPad first."
  exit 1
fi

echo "Uploading current.sqlite ($BYTES bytes) to R2…"
chmod +x scripts/publish-r2.sh
./scripts/publish-r2.sh "$LOCAL" "$OBJECT" application/octet-stream

echo "Published current.sqlite. Testers force-quit Heartbeat and open it again."
echo "Download: https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite"
