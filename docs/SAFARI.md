# Safari Extension Development

This project is maintained as an Xcode-packaged Safari Web Extension port for macOS, iOS, and iPadOS.

This Safari packaging documentation applies to the `6K6666/crw-extension` fork. The original CRW Extension codebase and project credit belong to [FULU-Foundation/CRW-Extension](https://github.com/FULU-Foundation/CRW-Extension); see [NOTICE.md](../NOTICE.md).

## Build And Sync

Build the Safari web extension:

```shell
npm run build-safari
```

Sync the built Safari resources into the Xcode project:

```shell
npm run sync-safari-resources
```

Confirm the generated Xcode resources match the latest Safari build:

```shell
diff -qr "dist/safari" "safari/Consumer Rights Wiki/Shared (Extension)/Resources"
```

The Xcode project is:

```text
safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj
```

The current fork distribution app bundle identifier is `com.aaroncooke.crw-safari-extension`; the extension bundle identifier is `com.aaroncooke.crw-safari-extension.Extension`.

## macOS Manual Testing

1. Run `npm run sync-safari-resources`.
2. Open `safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj` in Xcode.
3. Select the `Consumer Rights Wiki (macOS)` scheme.
4. Run the app.
5. In Safari, open Settings > Extensions and enable Consumer Rights Wiki.
6. Grant website access for All Websites.
7. Test these pages:
   - `https://www.amazon.com`
   - `https://ui.com`
   - `https://example.com`
8. Verify:
   - automatic inline popup appears on matching pages
   - toolbar popup opens and sizes correctly
   - Show on page displays the inline popup
   - options/settings opens
   - close, snooze, suppress site, and no-match states work

## iOS And iPadOS Manual Testing

1. Run `npm run sync-safari-resources`.
2. Open `safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj` in Xcode.
3. Select the `Consumer Rights Wiki (iOS)` scheme.
4. Choose an iOS Simulator, iPadOS Simulator, or connected device.
5. Run the app.
6. In the device Settings app, open Safari > Extensions.
7. Enable Consumer Rights Wiki and grant website access.
8. In Safari, open `https://www.amazon.com` and use the page menu to open Consumer Rights Wiki.
9. Verify:
   - matching popup content fits the Safari extension sheet
   - non-matching pages show the empty state
   - Show on page remains accessible
   - bottom safe-area spacing is acceptable
   - options/settings fallback works

For Simulator runs, verify the active booted device before installing or testing:

```shell
xcrun simctl list devices booted
```

Use the reported UDID for explicit Simulator commands when needed.

## Known Safari Behavior

- iOS Safari renders the extension sheet title as native Safari chrome. The extension popup document cannot independently style that title text, so title color should be treated as a Safari limitation.
- The iOS and iPadOS Settings app is the authoritative place to enable Safari extensions and grant website access.
- Xcode logs about WebPrivacy list data, AppIntents metadata extraction, GPU idle exits, or WebContent idle exits are usually non-blocking. Treat them as issues only when paired with a visible crash, hang, or extension failure.
- Simulator state can drift between devices. Confirm the booted simulator before relying on manual results.

## Release Validation

Run these checks before shipping a Safari build:

```shell
node --import tsx --test tests/*.test.ts
./node_modules/.bin/eslint "src/**/*.{ts,tsx}" "tests/**/*.ts" "scripts/**/*.ts"
npm run build-safari
npm run sync-safari-resources
diff -qr "dist/safari" "safari/Consumer Rights Wiki/Shared (Extension)/Resources"
xcodebuild -project "safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj" -scheme "Consumer Rights Wiki (macOS)" -configuration Debug -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project "safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj" -scheme "Consumer Rights Wiki (iOS)" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" CODE_SIGNING_ALLOWED=NO build
```

If a different simulator is booted, replace the iOS destination with the available simulator name and OS version.

## Direct macOS Distribution

Manual macOS distribution is supported through the macOS containing app. Users download `Consumer Rights Wiki.app`, open it once, then enable the Safari extension in Safari Settings > Extensions.

For normal public downloads outside the Mac App Store, sign the macOS app and extension with a Developer ID Application certificate and notarize the exported app. Development, Apple Development, Mac App Store, ad hoc, or unsigned builds are not suitable for public manual distribution because Gatekeeper will warn or block users.

Prerequisites:

- An active Apple Developer Program membership.
- A Developer ID Application certificate available in Keychain Access.
- Xcode signed in to the Apple Developer team you use for signing.
- The macOS app bundle ID `com.aaroncooke.crw-safari-extension` and extension bundle ID `com.aaroncooke.crw-safari-extension.Extension` registered for the team.
- Hardened Runtime enabled for the macOS targets.

Recommended Xcode release flow:

1. Run the release validation commands above.
2. Open `safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj`.
3. Select the `Consumer Rights Wiki (macOS)` scheme and `Any Mac` or `My Mac` as the destination.
4. Choose Product > Archive.
5. In Window > Organizer, select the archive and choose Distribute App.
6. Choose Direct Distribution or Custom > Developer ID.
7. Let Xcode manage signing automatically, upload for notarization, then export the notarized app when notarization completes.
8. Compress the exported `.app` into a `.zip` or package it in a `.dmg`.
9. Download the uploaded artifact on a clean Mac, open the app, enable the extension in Safari Settings > Extensions, and verify the extension works on matching and non-matching pages.

Command-line archive and export example:

```shell
mkdir -p build/release

xcodebuild \
  -project "safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj" \
  -scheme "Consumer Rights Wiki (macOS)" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "build/release/Consumer Rights Wiki.xcarchive" \
  -allowProvisioningUpdates \
  archive
```

Create `build/release/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>destination</key>
  <string>export</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>APPLE_TEAM_ID</string>
</dict>
</plist>
```

Then export:

```shell
xcodebuild \
  -exportArchive \
  -archivePath "build/release/Consumer Rights Wiki.xcarchive" \
  -exportPath "build/release/export" \
  -exportOptionsPlist "build/release/ExportOptions.plist" \
  -allowProvisioningUpdates
```

For command-line releases, package and notarize the exported app yourself:

```shell
ditto -c -k --keepParent \
  "build/release/export/Consumer Rights Wiki.app" \
  "build/release/Consumer Rights Wiki.zip"

xcrun notarytool submit \
  "build/release/Consumer Rights Wiki.zip" \
  --keychain-profile "crw-notary" \
  --wait

xcrun stapler staple "build/release/export/Consumer Rights Wiki.app"

ditto -c -k --keepParent \
  "build/release/export/Consumer Rights Wiki.app" \
  "build/release/Consumer Rights Wiki-notarized.zip"
```

Set up the `crw-notary` keychain profile once with an App Store Connect API key or app-specific password before using `notarytool`.

```shell
xcrun notarytool store-credentials "crw-notary" \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "APPLE_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

Verify the final artifact before publishing it:

```shell
codesign --verify --deep --strict --verbose=2 "build/release/export/Consumer Rights Wiki.app"
spctl --assess --type execute --verbose=4 "build/release/export/Consumer Rights Wiki.app"
```

Automated DMG packaging:

```shell
TEAM_ID="APPLE_TEAM_ID" npm run package:macos-dmg
```

To package the AltStore IPA and macOS DMG together, use the release wrapper:

```shell
TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:release
```

To run the validation suite first:

```shell
TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:release -- all --check
```

The output is:

```text
build/macos-dmg/Consumer Rights Wiki-1.0-2.dmg
```

The DMG contains `Consumer Rights Wiki.app` and an `/Applications` symlink so users can drag the app into Applications.

For manual testing, drag the app into `/Applications`, eject the DMG, then launch the app from `/Applications`. Do not enable the extension while running the app from the mounted DMG or from Xcode/DerivedData build output. Safari tracks extension registrations by the containing app copy, and multiple copies with the same bundle identifier can make extension state appear stale or wrong.

If a Developer ID Application certificate is installed, the packaging script uses it automatically. To specify one explicitly:

```shell
TEAM_ID="APPLE_TEAM_ID" MACOS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" npm run package:macos-dmg
```

To notarize during packaging, store notary credentials once and pass the profile name:

```shell
xcrun notarytool store-credentials "crw-notary" \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "APPLE_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"

TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:macos-dmg
```

If no Developer ID Application certificate is installed, the script creates a local development-signed DMG. That is useful for local testing, but it is not suitable for public distribution because Gatekeeper will reject it on other Macs.

## macOS Updates

A DMG does not push updates by itself. For direct-download macOS distribution, choose one of these update paths:

- Manual updates: publish a new DMG for each version and tell users to download the new release.
- Automatic updates: integrate Sparkle 2 and publish a signed appcast feed.
- App Store updates: distribute through the Mac App Store instead of direct DMG distribution.

Recommended direct-download update path:

1. Integrate Sparkle 2 into the macOS app target.
2. Generate a Sparkle EdDSA key pair.
3. Add `SUPublicEDKey` and `SUFeedURL` to the macOS app Info.plist.
4. Add a Check for Updates menu item or programmatic updater controller.
5. Package each release as a Developer ID signed and notarized DMG.
6. Use Sparkle's `generate_appcast` tool to create the appcast XML and update signatures.
7. Upload the DMG, release notes, appcast XML, and delta updates to HTTPS hosting.

Sparkle uses `CFBundleVersion` to decide whether an update is newer, so increment `CURRENT_PROJECT_VERSION` for every macOS release.

## iOS And iPadOS Distribution

iOS and iPadOS do not have the same public manual-download path as macOS. For Apple-supported distribution, use one of these channels:

- App Store: use this for public stable distribution.
- TestFlight: use this for beta or early-access distribution. External testing supports up to 10,000 testers, but the first external build must pass Apple beta review and builds expire after 90 days.
- Ad Hoc / Release Testing: use this only for a small known-device group. Every iPhone or iPad UDID must be registered in the Apple Developer account, and Apple limits registered devices per product family per membership year.
- Apple Business Manager / Apple School Manager custom app: use this for private distribution to specific organizations.
- Apple Developer Enterprise Program: use this only for proprietary internal employee apps. It is not for public distribution.
- EU alternative distribution: only applies in supported regions and requires Apple's alternative distribution terms, app review/notarization, and marketplace or web distribution setup.

Recommended path for this project:

1. Use TestFlight for the first non-developer iOS rollout.
2. Submit to the App Store when the release is stable.
3. Use Ad Hoc only when you personally know the device owners and can collect/register their device UDIDs.

TestFlight release flow:

1. Run the release validation commands above.
2. Open `safari/Consumer Rights Wiki/Consumer Rights Wiki.xcodeproj`.
3. Select the `Consumer Rights Wiki (iOS)` scheme.
4. Choose Product > Archive.
5. In Window > Organizer, select the archive and choose Distribute App.
6. Choose TestFlight & App Store, then upload to App Store Connect.
7. In App Store Connect, create or select the app record for `com.aaroncooke.crw-safari-extension`.
8. Add beta test information, export compliance answers, and a contact email.
9. Add internal testers first, then add an external tester group and submit the first external build for beta review.
10. After approval, send the TestFlight invite link. Testers install the app through TestFlight, then enable the extension in Settings > Safari > Extensions.

Ad Hoc / registered-device flow:

1. Collect each tester's iPhone or iPad UDID.
2. Register the devices in Certificates, Identifiers & Profiles.
3. Create or refresh an iOS distribution provisioning profile that includes those devices.
4. Archive the `Consumer Rights Wiki (iOS)` scheme.
5. In Organizer, choose Distribute App, then Release Testing / Ad Hoc.
6. Export the `.ipa`.
7. Install the `.ipa` using Apple Configurator, Xcode Devices and Simulators, MDM, or a properly configured over-the-air install manifest.

Ad Hoc builds are useful for controlled testing, but they are not a public distribution channel.

## AltStore Classic Sideloading

AltStore Classic can sideload a hosted `.ipa`, but this is community sideloading, not an Apple-supported public distribution channel. Users need AltStore and AltServer, and apps installed with a free Apple ID expire after 7 days unless refreshed.

This app must be installed with its app extension. If AltStore asks whether to keep or remove app extensions, keep extensions. Removing the embedded `Consumer Rights Wiki Extension.appex` removes the Safari extension and the app will not appear as a usable Safari extension.

This project uses two AltStore App IDs:

- `com.aaroncooke.crw-safari-extension`
- `com.aaroncooke.crw-safari-extension.Extension`

AltStore Classic users are limited by Apple's sideloading restrictions, including a limited number of active sideloaded apps and App IDs. Because this app includes one extension, it consumes one app slot and two App IDs.

Create the AltStore IPA:

```shell
npm run package:altstore
```

The output is:

```text
build/altstore/Consumer Rights Wiki-1.0-2.ipa
```

The package command does the following:

1. Builds the Safari extension web resources.
2. Syncs them into the Xcode Safari extension resources.
3. Builds the iOS app unsigned with `CODE_SIGNING_ALLOWED=NO`.
4. Packages `Consumer Rights Wiki.app` into a `Payload` directory and zips it as an `.ipa`.
5. Verifies that `Consumer Rights Wiki Extension.appex` is present in the IPA.

Manual AltStore install flow:

1. Publish the `.ipa` somewhere users can download it, such as a GitHub Release.
2. On the iPhone or iPad, install AltStore Classic and keep AltServer available for refreshes.
3. Download the `.ipa` on the device.
4. Open the `.ipa` in AltStore.
5. Keep app extensions if prompted.
6. Open the installed `Consumer Rights Wiki` app once.
7. Go to Settings > Safari > Extensions and enable Consumer Rights Wiki.
8. Grant website access and verify on a matching page.

AltStore source flow:

1. Publish the `.ipa` at a stable HTTPS URL.
2. Create an AltStore source JSON that points to the IPA.
3. Add the source URL to AltStore so users can install and receive updates from the source.

AltServer for macOS includes an `altsource` helper that can create or update source JSON from an IPA:

```shell
/Applications/AltServer.app/Contents/MacOS/altsource new \
  --ipa "build/altstore/Consumer Rights Wiki-1.0-2.ipa" \
  --name "Consumer Rights Wiki" \
  --app-name "Consumer Rights Wiki" \
  --app-developer "Consumer Rights Wiki" \
  --version-download-url "https://example.com/Consumer%20Rights%20Wiki-1.0-2.ipa" \
  -o "build/altstore/apps.json"
```

When publishing updates, upload the new IPA and add a new first entry in the source JSON `versions` array. AltStore checks the first compatible version entry to determine whether users have an update.

AltStore PAL is a separate EU-only marketplace path. For PAL, do not use this unsigned IPA flow; follow AltStore PAL's App Store Connect, notarization, Alternative Distribution Package, and source setup instead.
