# ce-init

`ce-init` 用于为 Codex 项目初始化 Compound Engineering（CE）工作流。它保留项目已有规则，只补充通用 CE 编排、repo-local 配置示例和产物目录。

本项目不复制 EveryInc 的 CE skills。运行前必须安装并启用官方插件：

```bash
codex plugin marketplace add EveryInc/compound-engineering-plugin
codex plugin add compound-engineering@compound-engineering-plugin
```

## 快速安装

### macOS / Linux

建议先查看安装脚本，再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.sh | bash
```

安装位置默认是：

```text
~/.local/share/ce-init/
~/.local/bin/ce-init
```

如果 `~/.local/bin` 不在 PATH 中，安装器会提示添加。

### Windows

在 PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.ps1 | iex
```

默认安装到 `%LOCALAPPDATA%\ce-init`，并将其 `bin` 目录加入用户 PATH。重新打开终端后即可使用 `ce-init`。

### 固定版本

默认安装器从 `main` 下载最新文件。发布 tag 后，可固定 ref，避免安装内容随分支变化：

```bash
curl -fsSL https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.sh | CE_INIT_REF=v0.1.0 bash
```

```powershell
$env:CE_INIT_REF = 'v0.1.0'
irm https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.ps1 | iex
```

重新运行相同安装命令即可升级。安装器也支持 `CE_INIT_REPOSITORY`、`CE_INIT_BASE_URL`、`CE_INIT_INSTALL_ROOT` 和 `CE_INIT_BIN_DIR` 覆盖。

## 使用

初始化当前项目：

```bash
ce-init
```

初始化指定项目：

```bash
ce-init /path/to/project
```

只检查、不修改：

```bash
ce-init --check /path/to/project
```

查看帮助和版本：

```bash
ce-init --help
ce-init --version
```

## 初始化行为

- 没有 `AGENTS.md` 时，从 `templates/AGENTS.md` 创建。
- 已有 `AGENTS.md` 时不覆盖，创建 `CE_AGENTS.md` 供人工合并。
- 已有且被定制的 `CE_AGENTS.md` 不会被覆盖。
- 创建 `docs/brainstorms/`、`docs/plans/`、`docs/reviews/` 和 `docs/solutions/`，并添加 `.gitkeep`。
- 从当前启用的官方插件复制 `.compound-engineering/config.local.example.yaml`。
- 确保 `.compound-engineering/config.local.yaml` 被 `.gitignore` 忽略。
- 完成后提示在 Codex 中运行 `$ce-setup` 做官方健康检查。

`ce-init` 不会自动启用 `$lfg`、worktree、功能分支、PR、自动合并或跨模型执行，也不会覆盖项目自己的部署、migration、外部系统和前端规则。

## 开发与测试

macOS / Linux：

```bash
bash -n bin/ce-init install.sh tests/test-unix.sh
tests/test-unix.sh
```

Windows PowerShell：

```powershell
./tests/ce-init.Tests.ps1
```

GitHub Actions 会在 Ubuntu、macOS 和 Windows 上执行对应测试。

## 许可证

[MIT](LICENSE)
