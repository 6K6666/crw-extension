#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj"
SCHEME="Consumer Rights Wiki (macOS)"
TEAM_ID="${TEAM_ID:-}"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData/macos-dmg"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/Release"
APP_NAME="Consumer Rights Wiki.app"
APP_PATH="$PRODUCTS_DIR/$APP_NAME"
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/Consumer Rights Wiki Extension.appex"
APP_ENTITLEMENTS="$ROOT_DIR/safari/Consumer Rights Wiki/macOS (App)/Release.entitlements"
EXTENSION_ENTITLEMENTS="$ROOT_DIR/safari/Consumer Rights Wiki/macOS (Extension)/Release.entitlements"
OUT_DIR="$ROOT_DIR/build/macos-dmg"
STAGING_DIR="$OUT_DIR/staging"
VOLUME_NAME="Consumer Rights Wiki"

developer_id_identity() {
  security find-identity -v -p codesigning |
    awk -F '"' '/Developer ID Application/ { print $2; exit }'
}

SIGN_IDENTITY="${MACOS_SIGNING_IDENTITY:-$(developer_id_identity)}"

run_xcodebuild() {
  if [[ -n "$TEAM_ID" ]]; then
    xcodebuild "$@" DEVELOPMENT_TEAM="$TEAM_ID" build
  else
    xcodebuild "$@" build
  fi
}

echo "Building macOS app..."
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Using Developer ID signing identity: $SIGN_IDENTITY"
  if [[ -z "$TEAM_ID" ]]; then
    echo "TEAM_ID is not set; xcodebuild will use any signing team configured outside this script." >&2
  fi
  run_xcodebuild \
    -quiet \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY"
else
  echo "No Developer ID Application identity found; building with automatic local signing."
  run_xcodebuild \
    -quiet \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -allowProvisioningUpdates
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle was not created: $APP_PATH" >&2
  exit 1
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  if [[ ! -d "$EXTENSION_PATH" ]]; then
    echo "Expected Safari extension bundle was not created: $EXTENSION_PATH" >&2
    exit 1
  fi

  echo "Re-signing Safari extension with release entitlements..."
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$EXTENSION_ENTITLEMENTS" \
    "$EXTENSION_PATH"

  echo "Re-signing app with release entitlements..."
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$APP_ENTITLEMENTS" \
    "$APP_PATH"

  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  codesign --verify --strict --verbose=2 "$EXTENSION_PATH"
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")"
DMG_PATH="$OUT_DIR/Consumer Rights Wiki-$VERSION-$BUILD_VERSION.dmg"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$OUT_DIR"

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing DMG..."
  codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "Submitting DMG for notarization with keychain profile: $NOTARY_PROFILE"
    NOTARY_RESULT_JSON="$OUT_DIR/notary-result.json"
    xcrun notarytool submit \
      "$DMG_PATH" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait \
      --output-format json | tee "$NOTARY_RESULT_JSON"

    NOTARY_SUBMISSION_ID="$(/usr/bin/plutil -extract id raw -o - "$NOTARY_RESULT_JSON")"
    NOTARY_STATUS="$(/usr/bin/plutil -extract status raw -o - "$NOTARY_RESULT_JSON")"

    if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
      echo "Notarization failed with status: $NOTARY_STATUS" >&2
      echo "Inspect the Apple notary log with:" >&2
      echo "xcrun notarytool log $NOTARY_SUBMISSION_ID --keychain-profile \"$NOTARY_PROFILE\"" >&2
      exit 1
    fi

    xcrun stapler staple "$DMG_PATH"
  else
    echo "Skipping notarization because NOTARY_PROFILE is not set."
  fi
else
  echo "Created local-signed DMG. Install a Developer ID Application certificate before public distribution."
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Created $DMG_PATH"
