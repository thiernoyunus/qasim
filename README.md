<p align="center">
  <img src="Art/app-icon-1024.png" width="112" alt="Qasim logo" />
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/header/glow.svg?title=Qasim&subtitle=A+focus+companion+for+your+Mac&logo=apple&mode=dark" />
    <img alt="Qasim" src="https://shieldcn.dev/header/glow.svg?title=Qasim&subtitle=A+focus+companion+for+your+Mac&logo=apple&mode=light" />
  </picture>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://shieldcn.dev/badge/macOS-14%2B-black.svg?variant=secondary&logo=apple" />
  <img alt="Swift" src="https://shieldcn.dev/badge/Swift-SwiftUI-f05138.svg?variant=secondary&logo=swift" />
  <a href="https://github.com/thiernoyunus/qasim"><img alt="Last commit" src="https://shieldcn.dev/github/last-commit/thiernoyunus/qasim.svg?variant=secondary" /></a>
  <a href="https://github.com/thiernoyunus/qasim"><img alt="Stars" src="https://shieldcn.dev/github/stars/thiernoyunus/qasim.svg?variant=secondary" /></a>
</p>

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

Focus activity and exact location stay on the Mac. “My location” prayer times are calculated locally. City mode sends only the selected city and country to `api.aladhan.com` to fetch prayer times. Website logos in Analytics and session setup are loaded straight from each site (for example `youtube.com/favicon.ico`), never from a third-party icon service.
