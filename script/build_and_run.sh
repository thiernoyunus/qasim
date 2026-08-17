#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${WICK_DERIVED_DATA:-/tmp/wick-derived}"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/Wick.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Wick"

pkill -x Wick >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/Wick.xcodeproj" \
  -scheme Wick \
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
    /usr/bin/log stream --info --style compact --predicate 'process == "Wick"'
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x Wick >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
