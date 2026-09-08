#!/bin/sh
# Same flow as install-ipad.sh. Targets Cory's iPhone only.
set -eu
cd "$(dirname "$0")"
export ALLOW_PHONE=1
export DEVICE_UDID="${DEVICE_UDID:-DAA3E01C-3F89-53E1-8361-E99825ED7DEA}"
export BUILD_DESTINATION="${BUILD_DESTINATION:-generic/platform=iOS}"
exec ./install-ipad.sh
