#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${CE_INIT_REPOSITORY:-ZhcChen/ce-init}"
REF="${CE_INIT_REF:-main}"
BASE_URL="${CE_INIT_BASE_URL:-https://raw.githubusercontent.com/$REPOSITORY/$REF}"
INSTALL_ROOT="${CE_INIT_INSTALL_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/ce-init}"
BIN_DIR="${CE_INIT_BIN_DIR:-$HOME/.local/bin}"

case "$(uname -s)" in
  Darwin|Linux) ;;
  *)
    echo "Error: install.sh 仅支持 macOS 和 Linux；Windows 请使用 install.ps1" >&2
    exit 1
    ;;
esac

download() {
  local source="$1"
  local destination="$2"
  local temporary="$destination.tmp.$$"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$source" -o "$temporary"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$temporary" "$source"
  else
    echo "Error: 需要 curl 或 wget 才能安装 ce-init" >&2
    exit 1
  fi

  mv "$temporary" "$destination"
}

mkdir -p "$INSTALL_ROOT/bin" "$INSTALL_ROOT/templates" "$BIN_DIR"
download "$BASE_URL/bin/ce-init" "$INSTALL_ROOT/bin/ce-init"
download "$BASE_URL/templates/AGENTS.md" "$INSTALL_ROOT/templates/AGENTS.md"
download "$BASE_URL/VERSION" "$INSTALL_ROOT/VERSION"
chmod +x "$INSTALL_ROOT/bin/ce-init"
ln -sfn "$INSTALL_ROOT/bin/ce-init" "$BIN_DIR/ce-init"

echo "ce-init 已安装到：$INSTALL_ROOT"
echo "命令入口：$BIN_DIR/ce-init"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "请将以下目录加入 PATH：$BIN_DIR" ;;
esac

echo "运行 ce-init --version 验证安装，运行 ce-init 初始化当前项目"
