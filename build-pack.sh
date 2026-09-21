#!/bin/sh
# Build / publish the Heartbeat pack testers open.
# The iPad never parses Excel. It only reads current.sqlite + pulse-cards.json.
#
# First time (creates the pack from a loaded iPad):
#   DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./build-pack.sh
#
# Daily (xlsx is archive only; pack comes off the iPad after one load):
#   R2_ACCESS_KEY_ID=… R2_SECRET_ACCESS_KEY=… R2_ACCOUNT_ID=… R2_BUCKET=heartbeat-packs \
#   DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./build-pack.sh "/path/Heartbeat Daily Report.xlsx"
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
UDID="${DEVICE_UDID:-}"
PROJECT="https://pcnjujfmlsklhrosxzlt.supabase.co"
KEY="sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd"
BUCKET="heartbeat-packs"
XLSX="${1:-}"

# Workbook archive stays on Supabase (cook still reads it from there).
upload_workbook() {
  NAME="$1"
  FILE="$2"
  TYPE="$3"
  CODE=$(curl -sS -o /tmp/heartbeat-pack-upload.txt -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $KEY" \
    -H "apikey: $KEY" \
    -H "Content-Type: $TYPE" \
    -H "x-upsert: true" \
    --data-binary @"$FILE" \
    "$PROJECT/storage/v1/object/$BUCKET/$NAME")
  if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
    CODE=$(curl -sS -o /tmp/heartbeat-pack-upload.txt -w "%{http_code}" \
      -X PUT \
      -H "Authorization: Bearer $KEY" \
      -H "apikey: $KEY" \
      -H "Content-Type: $TYPE" \
      -H "x-upsert: true" \
      --data-binary @"$FILE" \
      "$PROJECT/storage/v1/object/$BUCKET/$NAME")
  fi
  echo "$CODE"
}

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
  echo "Archiving workbook to Supabase (testers will not parse this)…"
  CODE=$(upload_workbook "Heartbeat Daily Report.xlsx" "$XLSX" "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
  echo "Workbook upload $CODE"
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
