#!/bin/sh
# Daily ingest. Excel never runs on iPhone/iPad.
#
# The GitHub repo is public, so the workbook is not a release asset and it
# is not uploaded to the public packs bucket (r2.dev). It goes to the private
# R2 bucket heartbeat-workbook, which has no public domain. GitHub Actions
# reads that bucket with the existing R2 secrets and cooks current.sqlite
# onto the public packs bucket.
#
# On this Mac, credentials are read for you. No exports.
#   1. Environment, if you already set R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY / R2_ACCOUNT_ID
#   2. macOS Keychain service heartbeat-r2
#        accounts: access_key_id, secret_access_key, account_id
#   3. ~/.config/heartbeat/r2.env (gitignored; not in this repo)
# One-time setup: ./scripts/setup-r2-keychain.sh
# Do not create a new token and do not set R2_BUCKET to heartbeat-packs.
# Optional R2_WORKBOOK_BUCKET overrides the private bucket name.
#
#   ./ingest-heartbeat.sh "/path/Heartbeat Daily Report.xlsx"
set -eu
cd "$(dirname "$0")"
# shellcheck source=scripts/load-r2-creds.sh
. ./scripts/load-r2-creds.sh

XLSX="${1:-}"
PUBLIC_BUCKET="${R2_BUCKET:-heartbeat-packs}"
WORKBOOK_BUCKET="${R2_WORKBOOK_BUCKET:-heartbeat-workbook}"
WORKBOOK_KEY="Heartbeat Daily Report.xlsx"

if [ -z "$XLSX" ]; then
  echo "Usage: ./ingest-heartbeat.sh \"/path/Heartbeat Daily Report.xlsx\""
  exit 1
fi
if [ ! -f "$XLSX" ]; then
  echo "File not found: $XLSX"
  exit 1
fi
if [ "$WORKBOOK_BUCKET" = "heartbeat-packs" ] || [ "$WORKBOOK_BUCKET" = "$PUBLIC_BUCKET" ]; then
  echo "Refusing to upload the workbook to the public packs bucket ($WORKBOOK_BUCKET)." >&2
  echo "Leave R2_BUCKET as the packs bucket. This script writes heartbeat-workbook." >&2
  exit 1
fi

if ! load_r2_credentials; then
  exit 1
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required to upload the workbook to the private R2 bucket." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
export AWS_EC2_METADATA_DISABLED=true
export AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED
export AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED

BYTES=$(wc -c < "$XLSX" | tr -d ' ')
echo "Uploading workbook ($BYTES bytes) to private bucket $WORKBOOK_BUCKET…"
aws s3 cp "$XLSX" "s3://${WORKBOOK_BUCKET}/${WORKBOOK_KEY}" \
  --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
  --content-type "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" \
  --cache-control "private, no-store"

echo "Workbook is in the private bucket."
if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed. The weekday schedule (every 15 minutes, 8:00 a.m.–5:45 p.m. Chicago) will pick the workbook up."
elif gh workflow run cook-heartbeat-pack.yml --repo murraycory-gif/FulfillmentHeartbeat-iOS; then
  echo
  echo "GitHub is cooking current.sqlite and publishing it to the public R2 packs bucket."
else
  echo "gh workflow run failed. The weekday schedule (every 15 minutes, 8:00 a.m.–5:45 p.m. Chicago) will pick the workbook up."
fi
echo "Watch: https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/actions"
echo "Pack: https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite"
echo "Testers: force-close Heartbeat, open it again. They never pick a file."
exit 0
