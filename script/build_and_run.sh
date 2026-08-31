#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${QASIM_DERIVED_DATA:-/tmp/qasim-derived}"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/Qasim.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Qasim"
INSTALLED_APP="/Applications/Qasim.app/Contents/MacOS/Qasim"

pkill -x Qasim >/dev/null 2>&1 || true
pkill -f "$INSTALLED_APP" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/Qasim.xcodeproj" \
  -scheme Qasim \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs|--telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate 'process == "Qasim"'
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x Qasim >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
