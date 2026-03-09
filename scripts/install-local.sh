#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Shift Input Switch.app"
INSTALL_DIR="${1:-$HOME/Applications}"

mkdir -p "$INSTALL_DIR"
"$ROOT_DIR/scripts/build-app.sh" release >/dev/null

SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"
TARGET_APP="$INSTALL_DIR/$APP_NAME"

rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"

echo "已安装到: $TARGET_APP"
echo "首次打开后，请到 系统设置 > 隐私与安全性 > 输入监控 授权。"
