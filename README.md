# Qasim

Qasim is a macOS focus companion that notices when you leave the apps or websites chosen for a session, then responds using the character and tone you selected.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Run locally

```sh
xcodegen generate
./script/build_and_run.sh --verify
```

## Release

Qasim ships as a notarized universal app for Apple silicon and Intel Macs. The release script creates an updater ZIP, a drag-to-Applications DMG, a GitHub release, and the Sparkle update feed.

```sh
xcrun notarytool store-credentials qasim-notary
./script/release.sh 1.0.1
```

The script expects a Developer ID Application certificate, GitHub CLI access to `thiernoyunus/qasim-updates`, and a clean local clone at `~/Coding/qasim-updates`.

## Privacy

Focus activity and exact location stay on the Mac. “My location” prayer times are calculated locally. City mode sends only the selected city and country to `api.aladhan.com` to fetch prayer times.
