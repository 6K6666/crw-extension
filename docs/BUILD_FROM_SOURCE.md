# Build From Source

This guide is for developers and maintainers who want to build Consumer Rights Wiki locally instead of installing a release artifact.

For release packaging details, see [SAFARI.md](SAFARI.md).

## Prerequisites

- macOS with Xcode installed.
- Node.js and npm.
- An Apple Developer account for signed macOS distribution.
- AltStore Classic if you want to test the iOS `.ipa` sideload flow.

The Xcode project is:

```text
safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj
```

The macOS app bundle identifier is:

```text
com.aaroncooke.crw-safari-extension
```

The Safari extension bundle identifier is:

```text
com.aaroncooke.crw-safari-extension.Extension
```

## Clone And Install

```shell
git clone https://github.com/6K6666/crw-extension.git
cd crw-extension
npm ci
```

## Build Web Extension Assets

```shell
npm run build-safari
```

The built Safari Web Extension assets are written to:

```text
dist/safari
```

Sync those assets into the Xcode project:

```shell
npm run sync-safari-resources
```

Confirm the generated resources match:

```shell
diff -qr "dist/safari" "safari/Consumer Rights Wiki/Shared (Extension)/Resources"
```

## Run Locally In Xcode

1. Open `safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj`.
2. Select `Consumer Rights Wiki (macOS)` or `Consumer Rights Wiki (iOS)`.
3. Run the target.
4. Enable the extension in Safari settings.

For macOS, open Safari > Settings > Extensions and enable Consumer Rights Wiki.

For iPhone and iPad, open Settings > Safari > Extensions and enable Consumer Rights Wiki.

## Validate Before Packaging

```shell
npm run check
```

Or run the same checks individually:

```shell
npm test
npm run lint
npm run build-safari
npm run sync-safari-resources
```

For additional Xcode validation commands, see [SAFARI.md](SAFARI.md).

## Package Both Release Artifacts

To create both public download artifacts in one run:

```shell
TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:release
```

That command syncs the Safari extension resources once, then creates:

```text
build/altstore/Consumer Rights Wiki-1.0-2.ipa
build/macos-dmg/Consumer Rights Wiki-1.0-2.dmg
```

Run only one target when needed:

```shell
npm run package:release -- ios
TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:release -- macos
```

Run the full validation suite first:

```shell
TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:release -- all --check
```

## Package For AltStore

```shell
npm run package:altstore
```

The output is:

```text
build/altstore/Consumer Rights Wiki-1.0-2.ipa
```

AltStore users must keep app extensions during install. Removing the embedded extension removes Safari support.

## Package For macOS DMG Distribution

Install a Developer ID Application certificate before making a public DMG. Confirm it is available:

```shell
security find-identity -v -p codesigning
```

Create or verify a notary profile:

```shell
xcrun notarytool store-credentials "crw-notary" \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "APPLE_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

Build, sign, notarize, and staple the DMG:

```shell
TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:macos-dmg
```

The output is:

```text
build/macos-dmg/Consumer Rights Wiki-1.0-2.dmg
```

Verify the final DMG:

```shell
xcrun stapler validate "build/macos-dmg/Consumer Rights Wiki-1.0-2.dmg"
spctl --assess --type open --context context:primary-signature --verbose=4 "build/macos-dmg/Consumer Rights Wiki-1.0-2.dmg"
```

The expected Gatekeeper source is:

```text
source=Notarized Developer ID
```
