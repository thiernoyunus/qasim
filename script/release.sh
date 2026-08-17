#!/usr/bin/env bash
# Build a signed Release build, package it, and publish it as a GitHub
# Release + Sparkle appcast entry so running copies of Wick can auto-update.
#
# Usage: script/release.sh 1.1        (bumps CFBundleShortVersionString to 1.1)
set -euo pipefail

VERSION="${1:?usage: script/release.sh <version, e.g. 1.1>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATES_REPO="${WICK_UPDATES_REPO:-$HOME/Coding/wick-updates}"
SPARKLE_BIN="${SPARKLE_BIN_DIR:-/tmp/sparkle-tools/bin}"
DERIVED_DATA="${WICK_RELEASE_DERIVED_DATA:-/tmp/wick-release-derived}"
ARCHIVE_DIR="/tmp/wick-release-archives"
SIGN_IDENTITY="${WICK_SIGN_IDENTITY:-Developer ID Application: THIERNO YOUNOUSSA DIALLO (257JN3YM2Y)}"

# Bump the marketing version and a monotonically increasing build number
# (epoch seconds is a lazy but always-increasing CFBundleVersion).
BUILD_NUMBER="$(date +%s)"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$VERSION" "$ROOT_DIR/Wick/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$ROOT_DIR/Wick/Info.plist"

rm -rf "$ARCHIVE_DIR" && mkdir -p "$ARCHIVE_DIR"

xcodebuild \
  -project "$ROOT_DIR/Wick.xcodeproj" \
  -scheme Wick \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/Wick.app"
ZIP_PATH="$ARCHIVE_DIR/Wick $VERSION.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Notarizing (this can take a few minutes)…"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile wick-notary --wait
xcrun stapler staple "$APP_BUNDLE"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

DOWNLOAD_URL="https://github.com/thiernoyunus/wick-updates/releases/download/v$VERSION/Wick $VERSION.zip"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/thiernoyunus/wick-updates/releases/download/v$VERSION/" \
  "$ARCHIVE_DIR"

gh release create "v$VERSION" "$ZIP_PATH" \
  --repo thiernoyunus/wick-updates \
  --title "Wick $VERSION" \
  --notes "Wick $VERSION"

cp "$ARCHIVE_DIR/appcast.xml" "$UPDATES_REPO/appcast.xml"
cd "$UPDATES_REPO"
git add appcast.xml
git commit -m "Wick $VERSION"
git push

echo "Released Wick $VERSION. Feed: $DOWNLOAD_URL"
