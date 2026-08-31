#!/usr/bin/env bash
# Build, sign, notarize, package, and publish Qasim + its Sparkle update feed.
# Usage: script/release.sh 1.0.1
set -euo pipefail

VERSION="${1:?usage: script/release.sh <version, e.g. 1.0.1>}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must look like 1.0.1" >&2; exit 2; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATES_REPO="${QASIM_UPDATES_REPO:-$HOME/Coding/qasim-updates}"
DERIVED_DATA="${QASIM_RELEASE_DERIVED_DATA:-/tmp/qasim-release-derived}"
ARCHIVE_DIR="${QASIM_RELEASE_ARCHIVE_DIR:-/tmp/qasim-release-archives}"
APPCAST_DIR="$ARCHIVE_DIR/appcast"
SIGN_IDENTITY="${QASIM_SIGN_IDENTITY:-Developer ID Application: THIERNO YOUNOUSSA DIALLO (257JN3YM2Y)}"
NOTARY_PROFILE="${QASIM_NOTARY_PROFILE:-qasim-notary}"
SPARKLE_BIN="${SPARKLE_BIN_DIR:-$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin}"

for command in xcodebuild xcodegen gh git security xcrun hdiutil; do
    command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done
[[ -d "$UPDATES_REPO/.git" ]] || { echo "Missing update-feed clone: $UPDATES_REPO" >&2; exit 1; }
git -C "$UPDATES_REPO" var GIT_AUTHOR_IDENT >/dev/null \
    || { echo "Git name/email is not configured for the update-feed commit." >&2; exit 1; }
security find-identity -v -p codesigning | grep -F "$SIGN_IDENTITY" >/dev/null \
    || { echo "Developer ID certificate not found: $SIGN_IDENTITY" >&2; exit 1; }
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || { echo "Notarization profile '$NOTARY_PROFILE' is missing or invalid." >&2; exit 1; }
gh auth status >/dev/null

EXISTING_DRAFT="$(gh release view "v$VERSION" --repo thiernoyunus/qasim-updates --json isDraft --jq .isDraft 2>/dev/null || true)"
if [[ "$EXISTING_DRAFT" == "true" ]]; then
    [[ -z "$(git -C "$UPDATES_REPO" status --porcelain)" ]] || { echo "Update-feed clone has uncommitted changes." >&2; exit 1; }
    git -C "$UPDATES_REPO" push
    gh release edit "v$VERSION" --repo thiernoyunus/qasim-updates --draft=false
    echo "Resumed and published Qasim $VERSION. Commit Qasim/Info.plist if needed."
    exit 0
elif [[ "$EXISTING_DRAFT" == "false" ]]; then
    echo "Release v$VERSION already exists." >&2
    exit 1
fi
[[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] || { echo "Commit or stash Qasim changes before releasing." >&2; exit 1; }
[[ -z "$(git -C "$UPDATES_REPO" status --porcelain)" ]] || { echo "Update-feed clone has uncommitted changes." >&2; exit 1; }

OLD_VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT_DIR/Qasim/Info.plist")"
OLD_BUILD="$(plutil -extract CFBundleVersion raw "$ROOT_DIR/Qasim/Info.plist")"
DRAFT_CREATED=0
FEED_COMMITTED=0
restore_version_on_failure() {
    if [[ "$DRAFT_CREATED" -eq 1 && "$FEED_COMMITTED" -eq 0 ]]; then
        gh release delete "v$VERSION" --repo thiernoyunus/qasim-updates --cleanup-tag --yes >/dev/null 2>&1 || true
    fi
    if [[ "$FEED_COMMITTED" -eq 0 ]]; then
        plutil -replace CFBundleShortVersionString -string "$OLD_VERSION" "$ROOT_DIR/Qasim/Info.plist"
        plutil -replace CFBundleVersion -string "$OLD_BUILD" "$ROOT_DIR/Qasim/Info.plist"
    fi
}
trap restore_version_on_failure EXIT

xcodegen generate --spec "$ROOT_DIR/project.yml"
[[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] \
    || { echo "XcodeGen changed project files. Commit them, then run the release again." >&2; exit 1; }
plutil -replace CFBundleShortVersionString -string "$VERSION" "$ROOT_DIR/Qasim/Info.plist"
plutil -replace CFBundleVersion -string "$(date +%s)" "$ROOT_DIR/Qasim/Info.plist"
rm -rf "$ARCHIVE_DIR"
mkdir -p "$APPCAST_DIR"

xcodebuild \
    -project "$ROOT_DIR/Qasim.xcodeproj" \
    -scheme Qasim \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    DEVELOPMENT_TEAM=257JN3YM2Y \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    OTHER_CODE_SIGN_FLAGS=--timestamp \
    build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/Qasim.app"
ZIP_PATH="$APPCAST_DIR/Qasim-$VERSION.zip"
DMG_PATH="$ARCHIVE_DIR/Qasim-$VERSION.dmg"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
ARCHS="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/Qasim")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "Qasim is not a universal build: $ARCHS" >&2; exit 1; }

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_BUNDLE"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
spctl --assess --type execute --verbose=2 "$APP_BUNDLE"

DMG_ROOT="$(mktemp -d)"
ditto "$APP_BUNDLE" "$DMG_ROOT/Qasim.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname Qasim -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_ROOT"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
hdiutil verify "$DMG_PATH"

[[ -x "$SPARKLE_BIN/generate_appcast" ]] || { echo "Sparkle release tools missing: $SPARKLE_BIN" >&2; exit 1; }
"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "https://github.com/thiernoyunus/qasim-updates/releases/download/v$VERSION/" \
    "$APPCAST_DIR"

gh release create "v$VERSION" "$ZIP_PATH" "$DMG_PATH" \
    --repo thiernoyunus/qasim-updates \
    --title "Qasim $VERSION" \
    --notes "Qasim $VERSION for macOS 14 and newer. Download the DMG, open it, and drag Qasim to Applications." \
    --draft
DRAFT_CREATED=1

cp "$APPCAST_DIR/appcast.xml" "$UPDATES_REPO/appcast.xml"
git -C "$UPDATES_REPO" add appcast.xml
git -C "$UPDATES_REPO" commit -m "Qasim $VERSION"
FEED_COMMITTED=1
git -C "$UPDATES_REPO" push
gh release edit "v$VERSION" --repo thiernoyunus/qasim-updates --draft=false

echo "Released Qasim $VERSION: https://github.com/thiernoyunus/qasim-updates/releases/tag/v$VERSION"
echo "Commit Qasim/Info.plist so the released version stays in source control."
