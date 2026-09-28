#!/bin/bash
set -euo pipefail
# Build and update the paired iPhone without uninstalling the app or erasing its data.
cd "$(dirname "$0")/.."
LITE_DEVICE_ID="${1:-00008110-00110D8E016A201E}"
LITE_DEVICE_BUILD="${LITE_DEVICE_BUILD:-/tmp/LitePopupDeviceBuild}"
xcodebuild -project lite.xcodeproj -scheme Lite -configuration Release \
  -destination "id=$LITE_DEVICE_ID" -derivedDataPath "$LITE_DEVICE_BUILD" \
  -allowProvisioningUpdates build > /tmp/lite-popup-device-build.log 2>&1
LITE_APP_PATH="$LITE_DEVICE_BUILD/Build/Products/Release-iphoneos/lite.app"
codesign --verify --deep --strict "$LITE_APP_PATH"
xcrun devicectl device install app --device "$LITE_DEVICE_ID" \
  --json-output /tmp/LitePopupDeviceInstall.json "$LITE_APP_PATH"
xcrun devicectl device process launch --device "$LITE_DEVICE_ID" --terminate-existing \
  --json-output /tmp/LitePopupDeviceLaunch.json aniket.lite
