#!/bin/bash
# One-time: store the existing R2 access key in the macOS Keychain.
# Service heartbeat-r2, accounts access_key_id, secret_access_key, account_id.
# Prompts with hidden input. Does not write a file in the repo.
#
#   ./scripts/setup-r2-keychain.sh
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo "Usage: ./scripts/setup-r2-keychain.sh" >&2
  echo "The script prompts for the three values. Do not pass them on the command line." >&2
  exit 1
fi
if ! command -v security >/dev/null 2>&1; then
  echo "macOS Keychain (the security command) is required." >&2
  exit 1
fi

prompt_hidden() {
  local label="$1"
  local value=""
  read -r -s -p "$label: " value
  printf '\n'
  if [ -z "$value" ]; then
    echo "Empty value for $label. Nothing was stored." >&2
    exit 1
  fi
  printf '%s' "$value"
}

store_item() {
  local account="$1"
  local value="$2"
  security add-generic-password -U \
    -s heartbeat-r2 \
    -a "$account" \
    -l "heartbeat-r2 $account" \
    -T /usr/bin/security \
    -w "$value"
}

echo "Paste the R2 access key GitHub Actions already uses. Input is hidden."
access_key_id=$(prompt_hidden "R2 access key id")
secret_access_key=$(prompt_hidden "R2 secret access key")
account_id=$(prompt_hidden "R2 account id")

store_item access_key_id "$access_key_id"
store_item secret_access_key "$secret_access_key"
store_item account_id "$account_id"

unset access_key_id secret_access_key account_id
echo "Stored access_key_id, secret_access_key, and account_id in Keychain service heartbeat-r2."
echo "Next: ./ingest-heartbeat.sh \"/path/Heartbeat Daily Report.xlsx\""
