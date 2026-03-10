#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Shift Input Switch.app"

if [[ $# -ge 1 ]]; then
  INSTALL_DIR="$1"
elif [[ -w /Applications ]]; then
  INSTALL_DIR="/Applications"
else
  INSTALL_DIR="$HOME/Applications"
fi

mkdir -p "$INSTALL_DIR"
"$ROOT_DIR/scripts/build-app.sh" release >/dev/null

SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"
TARGET_APP="$INSTALL_DIR/$APP_NAME"

rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"

echo "已安装到: $TARGET_APP"
echo "正在打开应用..."
open "$TARGET_APP"
echo "下一步："
echo "1. 到 系统设置 > 隐私与安全性 > 输入监控 授权。"
echo "2. 点击菜单栏里的应用图标。"
echo "3. 在菜单里点一次“开启开机自动启动”。"
