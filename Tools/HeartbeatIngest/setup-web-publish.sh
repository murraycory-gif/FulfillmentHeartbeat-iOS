#!/bin/bash
# One-time setup on Cory's Mac. Builds the cook, then installs the launchd
# watcher. The Cloudflare token stays in a file outside the repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOKEN_FILE="${HEARTBEAT_CF_TOKEN_FILE:-$HOME/.config/heartbeat/cloudflare-api-token}"
ICLOUD="${HEARTBEAT_ICLOUD_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Heartbeat_Reports}"

mkdir -p "$(dirname "$TOKEN_FILE")" "$ICLOUD"
if [[ ! -s "$TOKEN_FILE" ]]; then
  echo "Save the Cloudflare API token in:"
  echo "  $TOKEN_FILE"
  echo "The token needs Pages Edit on the account that owns fulfillment-heartbeat-web."
  echo "Then: chmod 600 \"$TOKEN_FILE\""
  echo "Do not commit that file and do not paste the token into chat."
  exit 1
fi
chmod 600 "$TOKEN_FILE"

if [[ ! -x "$ROOT/Tools/HeartbeatIngest/.build/release/HeartbeatIngest" ]]; then
  bash "$ROOT/Tools/HeartbeatIngest/prepare-sources.sh"
  (cd "$ROOT/Tools/HeartbeatIngest" && swift build -c release)
fi

if [[ "$(uname)" == "Darwin" ]]; then
  bash "$ROOT/Tools/HeartbeatIngest/cook-local.sh" --install
else
  echo "This machine is not macOS, so launchd was not installed."
  echo "On the Mac, run: ./Tools/HeartbeatIngest/cook-local.sh --install"
fi

cat << EOF
Watcher is ready for: $ICLOUD

Leave these workbooks in that folder:
  Heartbeat Daily Report.xlsx
  Schedule Review Week NN - Summary.xlsx

Saving either file cooks the pack and deploys only to
https://fulfillment-heartbeat-web.pages.dev
A cook error does not deploy. An unchanged file does not deploy again.

Cory clicks once if macOS asks for Files and Folders / iCloud Drive access. Allow it.
EOF
