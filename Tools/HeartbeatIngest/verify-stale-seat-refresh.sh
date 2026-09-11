#!/usr/bin/env bash
# Mac-only. Proves a usable OLD local company seat is replaced by a newer
# cloud pack without deleting the app (HB-0828.403 / 729).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Run this on a Mac with the Heartbeat project."
  echo "Test: FulfillmentHeartbeatTests/HeartbeatMathTests/testStaleCompanySeatIsReplacedByNewerCloudPackWithoutDelete"
  exit 1
fi

DEST="${STALE_SEAT_DEST:-platform=macOS,variant=Mac Catalyst}"
xcodebuild test \
  -project FulfillmentHeartbeat.xcodeproj \
  -scheme FulfillmentHeartbeat \
  -destination "$DEST" \
  -only-testing:FulfillmentHeartbeatTests/HeartbeatMathTests/testStaleCompanySeatIsReplacedByNewerCloudPackWithoutDelete
