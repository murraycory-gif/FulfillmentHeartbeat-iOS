#!/bin/sh
# Copy an Excel file from this Mac into Heartbeat on the iPad.
# Usage:
#   DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./push-workbook.sh "/path/to/Star Ratings.xlsx"
set -eu
cd "$(dirname "$0")"

BUNDLE_ID="com.corymurray.FulfillmentHeartbeat"
UDID="${DEVICE_UDID:-}"
FILE="${1:-}"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Usage: DEVICE_UDID=... ./push-workbook.sh /path/to/file.xlsx"
  exit 1
fi

if [ -z "$UDID" ]; then
  echo "Set DEVICE_UDID to the iPad UDID."
  exit 1
fi

NAME=$(basename "$FILE")
echo "Copying $NAME onto the iPad Heartbeat folder…"

if xcrun devicectl device copy to \
  --device "$UDID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "$FILE" \
  --destination "Documents/$NAME"; then
  echo "Copied. Open Heartbeat → Upload → Pick file → $NAME"
  exit 0
fi

echo "devicectl copy failed. Use Finder instead:"
echo "  Finder → your iPad in the sidebar → Files → Heartbeat → drop $NAME there"
exit 1
