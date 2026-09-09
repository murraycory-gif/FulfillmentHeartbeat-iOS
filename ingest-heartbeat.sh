#!/bin/sh
# Daily ingest. Excel never runs on iPhone/iPad.
#
# 1. Upload Heartbeat Daily Report.xlsx to the bucket.
# 2. GitHub cooks current.sqlite (Mac does not need to be on).
# 3. Testers open Heartbeat — they only download the pack.
#
# Usage:
#   ./ingest-heartbeat.sh "/path/Heartbeat Daily Report.xlsx"
set -eu
cd "$(dirname "$0")"

PROJECT="https://pcnjujfmlsklhrosxzlt.supabase.co"
KEY="sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd"
BUCKET="heartbeat-packs"
XLSX="${1:-}"

if [ -z "$XLSX" ]; then
  echo "Usage: ./ingest-heartbeat.sh \"/path/Heartbeat Daily Report.xlsx\""
  exit 1
fi
if [ ! -f "$XLSX" ]; then
  echo "File not found: $XLSX"
  exit 1
fi

BYTES=$(wc -c < "$XLSX" | tr -d ' ')
echo "Uploading workbook ($BYTES bytes)…"
CODE=$(curl -sS -o /tmp/heartbeat-xlsx-upload.txt -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $KEY" \
  -H "apikey: $KEY" \
  -H "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" \
  -H "x-upsert: true" \
  --data-binary @"$XLSX" \
  "$PROJECT/storage/v1/object/$BUCKET/Heartbeat%20Daily%20Report.xlsx")
if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  CODE=$(curl -sS -o /tmp/heartbeat-xlsx-upload.txt -w "%{http_code}" \
    -X PUT \
    -H "Authorization: Bearer $KEY" \
    -H "apikey: $KEY" \
    -H "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" \
    -H "x-upsert: true" \
    --data-binary @"$XLSX" \
    "$PROJECT/storage/v1/object/$BUCKET/Heartbeat%20Daily%20Report.xlsx")
fi
if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  echo "Workbook upload failed ($CODE)."
  cat /tmp/heartbeat-xlsx-upload.txt
  exit 1
fi

echo "Workbook is in the bucket."
if command -v gh >/dev/null 2>&1; then
  echo "Starting the cloud kitchen…"
  gh workflow run cook-heartbeat-pack.yml --repo murraycory-gif/FulfillmentHeartbeat-iOS || true
fi
echo
echo "GitHub is cooking current.sqlite. Usually a few minutes."
echo "Watch: https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/actions"
echo "Testers: force-close Heartbeat, open it again. They never pick a file."
