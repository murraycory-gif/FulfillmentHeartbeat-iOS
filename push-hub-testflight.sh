#!/bin/sh
# Archive HUB Prediction only. Does not touch Heartbeat.
set -eu
cd "$(dirname "$0")"

if [ ! -f HubPrediction.xcodeproj/project.pbxproj ]; then
  echo "HubPrediction.xcodeproj is missing. You are in the wrong folder."
  exit 1
fi
if ! grep -q 'com.corymurray.HubPrediction' HubPrediction.xcodeproj/project.pbxproj; then
  echo "Bundle ID com.corymurray.HubPrediction is missing from the project."
  exit 1
fi

DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if ! echo "$DEVELOPER_DIR" | grep -q 'Xcode.app/Contents/Developer'; then
  echo "xcodebuild needs full Xcode, not Command Line Tools."
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

ARCHIVE="$HOME/Desktop/HubPrediction.xcarchive"
rm -rf "$ARCHIVE"
echo "Archiving HUB Prediction (com.corymurray.HubPrediction)."
echo "This is not Heartbeat."
xcodebuild \
  -project HubPrediction.xcodeproj \
  -scheme HubPrediction \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  archive \
  -archivePath "$ARCHIVE"
echo "ARCHIVE DONE: $ARCHIVE"
echo "Organizer → Distribute App → App Store Connect → Upload"
echo "App Store Connect app: HUB Prediction · team M7FL68Q43A"
open -a Xcode "$(pwd)/HubPrediction.xcodeproj"
open -a Xcode "$ARCHIVE"
