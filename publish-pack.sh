#!/bin/sh
# Publish the on-device SQLite pack to Supabase so testers never parse Excel.
# Usage:
#   DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./publish-pack.sh
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
UDID="${DEVICE_UDID:-}"
PROJECT="https://pcnjujfmlsklhrosxzlt.supabase.co"
KEY="sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd"
BUCKET="heartbeat-packs"
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

echo "Uploading current.sqlite ($BYTES bytes) to $BUCKET…"
CODE=$(curl -sS -o /tmp/heartbeat-pack-upload.txt -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $KEY" \
  -H "apikey: $KEY" \
  -H "Content-Type: application/octet-stream" \
  -H "x-upsert: true" \
  --data-binary @"$LOCAL" \
  "$PROJECT/storage/v1/object/$BUCKET/$OBJECT")

if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  CODE=$(curl -sS -o /tmp/heartbeat-pack-upload.txt -w "%{http_code}" \
    -X PUT \
    -H "Authorization: Bearer $KEY" \
    -H "apikey: $KEY" \
    -H "Content-Type: application/octet-stream" \
    -H "x-upsert: true" \
    --data-binary @"$LOCAL" \
    "$PROJECT/storage/v1/object/$BUCKET/$OBJECT")
fi

if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  echo "Upload failed ($CODE)."
  cat /tmp/heartbeat-pack-upload.txt
  echo
  echo "In Supabase → Storage → heartbeat-packs → Policies, allow INSERT/UPDATE for anon."
  exit 1
fi

echo "Published current.sqlite. Testers open Heartbeat and the pack is already there."
