#!/bin/sh
# Publish one file to the Heartbeat R2 bucket via the S3-compatible API.
# Required env (GitHub Actions secrets or a local export — do not hardcode):
#   R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID R2_BUCKET
#
# Usage: ./scripts/publish-r2.sh <local-file> <object-key> [content-type]
set -eu

FILE="${1:-}"
KEY="${2:-}"
TYPE="${3:-application/octet-stream}"

if [ -z "$FILE" ] || [ -z "$KEY" ] || [ ! -f "$FILE" ]; then
  echo "Usage: $0 <local-file> <object-key> [content-type]"
  exit 1
fi

missing=""
for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID R2_BUCKET; do
  eval "val=\${$var:-}"
  if [ -z "$val" ]; then
    missing="$missing $var"
  fi
done
if [ -n "$missing" ]; then
  echo "Missing R2 env:$missing"
  echo "Set the GitHub Actions secrets (or export the same names locally) and retry."
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required to publish to R2."
  exit 1
fi

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
export AWS_EC2_METADATA_DISABLED=true
# AWS CLI v2 checksum headers are rejected by R2 unless calculation is optional.
export AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED
export AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED

ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

aws s3 cp "$FILE" "s3://${R2_BUCKET}/${KEY}" \
  --endpoint-url "$ENDPOINT" \
  --content-type "$TYPE" \
  --cache-control "public, max-age=60"

echo "Published s3://${R2_BUCKET}/${KEY}"
