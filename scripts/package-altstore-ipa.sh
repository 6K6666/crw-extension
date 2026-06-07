#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj"
SCHEME="Consumer Rights Wiki (iOS)"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData/altstore-ios"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/Release-iphoneos"
APP_NAME="Consumer Rights Wiki.app"
APP_PATH="$PRODUCTS_DIR/$APP_NAME"
OUT_DIR="$ROOT_DIR/build/altstore"
PAYLOAD_DIR="$OUT_DIR/Payload"
EXTENSION_PLIST="$APP_NAME/PlugIns/Consumer Rights Wiki Extension.appex/Info.plist"

echo "Building unsigned iOS app for AltStore..."
xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle was not created: $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Info.plist")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Info.plist")"
IPA_PATH="$OUT_DIR/Consumer Rights Wiki-$VERSION-$BUILD_VERSION.ipa"

rm -rf "$PAYLOAD_DIR" "$IPA_PATH"
mkdir -p "$PAYLOAD_DIR"
ditto "$APP_PATH" "$PAYLOAD_DIR/$APP_NAME"

if [[ ! -f "$PAYLOAD_DIR/$EXTENSION_PLIST" ]]; then
  echo "Staged IPA payload is missing the Safari web extension appex." >&2
  exit 1
fi

(
  cd "$OUT_DIR"
  /usr/bin/zip -qry "$(basename "$IPA_PATH")" Payload
)

rm -rf "$PAYLOAD_DIR"

IPA_FILE_LIST="$(/usr/bin/unzip -Z1 "$IPA_PATH")"

if ! grep -Fxq "Payload/$EXTENSION_PLIST" <<<"$IPA_FILE_LIST"; then
  echo "Packaged IPA is missing the Safari web extension appex." >&2
  exit 1
fi

echo "Created $IPA_PATH"
