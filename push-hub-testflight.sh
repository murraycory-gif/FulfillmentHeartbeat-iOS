#!/bin/sh
# Archive HUB Prediction for TestFlight. Run on the Mac.
# Same flow as push-testflight.sh, different app. Does not touch Heartbeat.
set -eu
cd "$(dirname "$0")"
ARCHIVE="$HOME/Desktop/HubPrediction.xcarchive"
rm -rf "$ARCHIVE"
echo "Archiving HUB Prediction. Wait for ARCHIVE SUCCEEDED. Do not close this window."
xcodebuild \
  -project HubPrediction.xcodeproj \
  -scheme HubPrediction \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -allowProvisioningUpdates \
  archive \
  -archivePath "$ARCHIVE"
echo "ARCHIVE DONE: $ARCHIVE"
open -a Xcode "$(pwd)/HubPrediction.xcodeproj"
open -a Xcode "$ARCHIVE"
