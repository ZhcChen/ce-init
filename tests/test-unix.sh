#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/bin/ce-init"
TEMPLATE="$ROOT_DIR/templates/AGENTS.md"
TEST_ROOT="$(mktemp -d)"
PLUGIN_ROOT="$TEST_ROOT/plugin with spaces"
FAKE_CODEX="$TEST_ROOT/codex"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "文件不存在：$1"
}

assert_contains() {
  grep -Fq -- "$2" "$1" || fail "未在 $1 中找到：$2"
}

mkdir -p "$PLUGIN_ROOT/skills/ce-setup/references"
printf 'docs_root: docs\n' > "$PLUGIN_ROOT/skills/ce-setup/references/config-template.yaml"
cat > "$FAKE_CODEX" <<EOF
#!/usr/bin/env bash
echo 'compound-engineering@compound-engineering-plugin  installed, enabled  3.21.0  $PLUGIN_ROOT'
EOF
chmod +x "$FAKE_CODEX"

# 新项目初始化
TARGET1="$TEST_ROOT/target1"
mkdir -p "$TARGET1"
printf 'existing-ignore-rule' > "$TARGET1/.gitignore"
CODEX_BIN="$FAKE_CODEX" "$SCRIPT" "$TARGET1" > "$TEST_ROOT/target1.out"
cmp "$TEMPLATE" "$TARGET1/AGENTS.md"
cmp "$PLUGIN_ROOT/skills/ce-setup/references/config-template.yaml" "$TARGET1/.compound-engineering/config.local.example.yaml"
for directory in brainstorms plans reviews solutions; do
  assert_file "$TARGET1/docs/$directory/.gitkeep"
done
[[ "$(wc -l < "$TARGET1/.gitignore" | tr -d ' ')" -eq 2 ]] || fail '.gitignore 换行不正确'
CODEX_BIN="$FAKE_CODEX" "$SCRIPT" --check "$TARGET1" > "$TEST_ROOT/check.out"
assert_contains "$TEST_ROOT/check.out" 'CE 初始化状态正常'

# 已有规则必须保留，重复运行不得覆盖人工合并文件
TARGET2="$TEST_ROOT/target2"
mkdir -p "$TARGET2"
printf 'existing agents\n' > "$TARGET2/AGENTS.md"
CODEX_BIN="$FAKE_CODEX" "$SCRIPT" "$TARGET2" > "$TEST_ROOT/target2.out"
assert_contains "$TARGET2/AGENTS.md" 'existing agents'
cmp "$TEMPLATE" "$TARGET2/CE_AGENTS.md"
printf 'custom merge rules\n' > "$TARGET2/CE_AGENTS.md"
CODEX_BIN="$FAKE_CODEX" "$SCRIPT" "$TARGET2" > "$TEST_ROOT/rerun.out"
assert_contains "$TARGET2/CE_AGENTS.md" 'custom merge rules'
[[ "$(grep -Fc '.compound-engineering/config.local.yaml' "$TARGET2/.gitignore")" -eq 1 ]] || fail '.gitignore 规则重复'

# 插件缺失时不得创建目标目录
NO_PLUGIN_CODEX="$TEST_ROOT/codex-no-plugin"
cat > "$NO_PLUGIN_CODEX" <<'EOF'
#!/usr/bin/env bash
echo 'unrelated@marketplace  installed, enabled  1.0.0  /tmp/unrelated'
EOF
chmod +x "$NO_PLUGIN_CODEX"
TARGET3="$TEST_ROOT/target3"
if CODEX_BIN="$NO_PLUGIN_CODEX" "$SCRIPT" "$TARGET3" > /dev/null 2> "$TEST_ROOT/no-plugin.err"; then
  fail '插件缺失时应失败'
fi
[[ ! -e "$TARGET3" ]] || fail '插件预检前修改了目标目录'

# Unix 安装器从可替换的 raw 基址安装，并提供 PATH 命令
INSTALL_HOME="$TEST_ROOT/home"
INSTALL_ROOT="$TEST_ROOT/install-root"
BIN_DIR="$TEST_ROOT/bin"
HOME="$INSTALL_HOME" \
CE_INIT_BASE_URL="file://$ROOT_DIR" \
CE_INIT_INSTALL_ROOT="$INSTALL_ROOT" \
CE_INIT_BIN_DIR="$BIN_DIR" \
bash "$ROOT_DIR/install.sh" > "$TEST_ROOT/install.out"
assert_file "$INSTALL_ROOT/bin/ce-init"
assert_file "$INSTALL_ROOT/templates/AGENTS.md"
[[ -L "$BIN_DIR/ce-init" ]] || fail '未创建 ce-init 命令软链接'
[[ "$($BIN_DIR/ce-init --version)" == "$(tr -d '\r\n' < "$ROOT_DIR/VERSION")" ]] || fail '安装版本不匹配'

echo 'PASS: Unix ce-init tests'
