#!/bin/sh
# Archive Heartbeat for TestFlight upload.
# Run on the Mac. Does not upload by itself — Organizer does that.
set -eu
cd "$(dirname "$0")"
git fetch origin main
git pull --ff-only origin main || true
ARCHIVE="$HOME/Desktop/FulfillmentHeartbeat.xcarchive"
rm -rf "$ARCHIVE"
echo "Archiving. Wait for ARCHIVE SUCCEEDED. Do not close this window."
xcodebuild \
  -workspace FulfillmentHeartbeat.xcworkspace \
  -scheme FulfillmentHeartbeat \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -allowProvisioningUpdates \
  archive \
  -archivePath "$ARCHIVE"
echo "ARCHIVE DONE: $ARCHIVE"
open -a Xcode "$(pwd)/FulfillmentHeartbeat.xcworkspace"
open -a Xcode "$ARCHIVE"
