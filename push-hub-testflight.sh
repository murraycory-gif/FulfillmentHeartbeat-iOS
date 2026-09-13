#!/bin/sh
# Archive HUB Prediction for TestFlight. Run on the Mac.
# Same flow as push-testflight.sh, different app. Does not touch Heartbeat.
set -eu
cd "$(dirname "$0")"

DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if ! echo "$DEVELOPER_DIR" | grep -q 'Xcode.app/Contents/Developer'; then
  echo "xcodebuild needs full Xcode, not Command Line Tools."
  echo "Run this once, then retry:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "If Xcode is named something else, open it once, then:"
  echo "  xcode-select -p"
  exit 1
fi

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
