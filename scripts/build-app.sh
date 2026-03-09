#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "用法: scripts/build-app.sh [debug|release]" >&2
    exit 1
    ;;
esac

PRODUCT_NAME="ShiftInputSwitch"
APP_NAME="Shift Input Switch"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
TEMPLATE_PATH="$ROOT_DIR/Config/Info.plist.template"
PLIST_PATH="$CONTENTS_DIR/Info.plist"

BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.liumengdi.shift-input-switch}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}"

swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$PRODUCT_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

sed \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__EXECUTABLE__|$PRODUCT_NAME|g" \
  -e "s|__BUNDLE_IDENTIFIER__|$BUNDLE_IDENTIFIER|g" \
  -e "s|__VERSION__|$VERSION|g" \
  -e "s|__BUILD__|$BUILD_NUMBER|g" \
  "$TEMPLATE_PATH" > "$PLIST_PATH"

plutil -lint "$PLIST_PATH" >/dev/null
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
