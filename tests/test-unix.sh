#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/bin/ce-init"
TEMPLATE="$ROOT_DIR/templates/AGENTS.md"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"
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

mkdir -p "$TEST_HOME" "$PLUGIN_ROOT/skills/ce-setup/references"
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
HOME="$TEST_HOME" CODEX_BIN="$FAKE_CODEX" "$SCRIPT" --check "$TARGET1" > "$TEST_ROOT/check.out"
assert_contains "$TEST_ROOT/check.out" 'CE 初始化状态正常'

# 旧版 tool map 只由显式迁移命令清理；检查应报告，普通初始化不得改写
ACTIVE_CODEX_HOME="$TEST_ROOT/custom-codex"
DEFAULT_AGENTS="$TEST_HOME/.codex/AGENTS.md"
PROFILE_AGENTS="$ACTIVE_CODEX_HOME/profiles/work/AGENTS.md"
mkdir -p "$(dirname "$DEFAULT_AGENTS")" "$(dirname "$PROFILE_AGENTS")"
cat > "$DEFAULT_AGENTS" <<'EOF'
# 保留规则
<!-- BEGIN COMPOUND CODEX TOOL MAP -->
- obsolete mapping
<!-- END COMPOUND CODEX TOOL MAP -->
# 后续规则
EOF
printf '# 保留规则\r\n<!-- BEGIN COMPOUND CODEX TOOL MAP -->\r\n- obsolete mapping\r\n<!-- END COMPOUND CODEX TOOL MAP -->\r\n# 后续规则' > "$PROFILE_AGENTS"
cp "$DEFAULT_AGENTS" "$TEST_ROOT/default-agents.before"
if HOME="$TEST_HOME" CODEX_HOME="$ACTIVE_CODEX_HOME" CODEX_BIN="$FAKE_CODEX" "$SCRIPT" --check "$TARGET1" > "$TEST_ROOT/legacy-check.out"; then
  fail '存在旧版 tool map 时 --check 应失败'
fi
assert_contains "$TEST_ROOT/legacy-check.out" '废弃：旧版 CE tool map'
cmp "$TEST_ROOT/default-agents.before" "$DEFAULT_AGENTS"

CODEX_BIN="$TEST_ROOT/missing-codex" HOME="$TEST_HOME" CODEX_HOME="$ACTIVE_CODEX_HOME" \
  "$SCRIPT" --cleanup-legacy-tool-map > "$TEST_ROOT/cleanup.out"
assert_contains "$TEST_ROOT/cleanup.out" '已清理旧版 CE tool map'
for agents_file in "$DEFAULT_AGENTS" "$PROFILE_AGENTS"; do
  assert_contains "$agents_file" '# 保留规则'
  assert_contains "$agents_file" '# 后续规则'
  if grep -Fq 'COMPOUND CODEX TOOL MAP' "$agents_file"; then
    fail "旧版 tool map 未清理：$agents_file"
  fi
done
printf '# 保留规则\n# 后续规则\n' > "$TEST_ROOT/default-agents.expected"
printf '# 保留规则\r\n# 后续规则' > "$TEST_ROOT/profile-agents.expected"
cmp "$TEST_ROOT/default-agents.expected" "$DEFAULT_AGENTS"
cmp "$TEST_ROOT/profile-agents.expected" "$PROFILE_AGENTS"

cat > "$DEFAULT_AGENTS" <<'EOF'
# 前置文件也不得修改
<!-- BEGIN COMPOUND CODEX TOOL MAP -->
- valid but must remain
<!-- END COMPOUND CODEX TOOL MAP -->
EOF
cat > "$PROFILE_AGENTS" <<'EOF'
# 残缺文件不得修改
<!-- BEGIN COMPOUND CODEX TOOL MAP -->
- missing end marker
EOF
cp "$DEFAULT_AGENTS" "$TEST_ROOT/malformed.before"
cp "$PROFILE_AGENTS" "$TEST_ROOT/malformed-profile.before"
if HOME="$TEST_HOME" CODEX_HOME="$ACTIVE_CODEX_HOME" "$SCRIPT" --cleanup-legacy-tool-map > /dev/null 2> "$TEST_ROOT/malformed.err"; then
  fail '残缺 tool map 标记应拒绝清理'
fi
cmp "$TEST_ROOT/malformed.before" "$DEFAULT_AGENTS"
cmp "$TEST_ROOT/malformed-profile.before" "$PROFILE_AGENTS"
assert_contains "$TEST_ROOT/malformed.err" '标记不完整'
rm -f "$DEFAULT_AGENTS" "$PROFILE_AGENTS"

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
INSTALL_HOME="$TEST_HOME"
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
