<div align="center">

# ce-init

为 Codex 项目快速建立一致、可维护的 Compound Engineering 工作流。

[![CI](https://github.com/ZhcChen/ce-init/actions/workflows/test.yml/badge.svg)](https://github.com/ZhcChen/ce-init/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/tag/ZhcChen/ce-init?label=release&sort=semver)](https://github.com/ZhcChen/ce-init/tree/v0.1.0)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue.svg)](#支持平台)
[![Codex](https://img.shields.io/badge/Codex-Compound%20Engineering-black.svg)](https://github.com/EveryInc/compound-engineering-plugin)

</div>

`ce-init` 保留项目已有规则，只补充通用 CE 编排、repo-local 配置示例和标准产物目录。它不复制 EveryInc 的 CE skills，也不会替项目决定分支、PR、部署或 migration 策略。

## 能力概览

| 能力 | 说明 |
| --- | --- |
| 跨平台 | 提供 Bash 与 PowerShell 原生实现 |
| 保护现有规则 | 不覆盖已有 `AGENTS.md` 或定制过的 `CE_AGENTS.md` |
| 官方配置同步 | 从当前启用的 CE 插件复制最新 repo-local 配置示例 |
| 可重复执行 | 重复初始化不会追加重复规则或破坏已有内容 |
| 健康检查 | `ce-init --check` 只检查项目，不修改文件 |
| 可固定版本 | 安装器支持通过 Git ref 固定发布版本 |

## 支持平台

| 平台 | 命令实现 | 安装器 | CI |
| --- | --- | --- | --- |
| macOS | Bash | `install.sh` | 已验证 |
| Linux | Bash | `install.sh` | 已验证 |
| Windows | PowerShell | `install.ps1` | 已验证 |

## 前置条件

需要安装 Codex CLI，并启用 EveryInc 官方 Compound Engineering 插件：

```bash
codex plugin marketplace add EveryInc/compound-engineering-plugin
codex plugin add compound-engineering@compound-engineering-plugin
```

可以通过以下命令确认插件状态：

```bash
codex plugin list
```

## 快速安装

### macOS / Linux

建议先打开并审阅 [`install.sh`](install.sh)，然后执行：

```bash
curl -fsSL https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.sh | bash
```

默认安装位置：

```text
~/.local/share/ce-init/
~/.local/bin/ce-init
```

如果 `~/.local/bin` 不在 PATH 中，安装器会输出对应提示。

### Windows

建议先打开并审阅 [`install.ps1`](install.ps1)，然后在 PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.ps1 | iex
```

默认安装到 `%LOCALAPPDATA%\ce-init`，并将其 `bin` 目录加入用户 PATH。重新打开终端后即可使用。

### 固定版本

默认从 `main` 安装最新内容。需要可复现安装时，固定到发布 tag：

```bash
curl -fsSL https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.sh | CE_INIT_REF=v0.1.0 bash
```

```powershell
$env:CE_INIT_REF = 'v0.1.0'
irm https://raw.githubusercontent.com/ZhcChen/ce-init/main/install.ps1 | iex
```

重新运行相同命令即可升级。

<details>
<summary>安装器高级配置</summary>

安装器支持以下环境变量：

| 环境变量 | 用途 |
| --- | --- |
| `CE_INIT_REF` | 指定 Git branch、tag 或 commit |
| `CE_INIT_REPOSITORY` | 指定 GitHub 仓库，默认 `ZhcChen/ce-init` |
| `CE_INIT_BASE_URL` | 覆盖完整下载基址 |
| `CE_INIT_INSTALL_ROOT` | 覆盖安装目录 |
| `CE_INIT_BIN_DIR` | 覆盖命令入口目录 |

</details>

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

初始化完成后，在 Codex 中运行 `$ce-setup`，执行官方健康检查和交互式本地配置。

## 初始化结果

```text
project/
├── AGENTS.md
├── .compound-engineering/
│   └── config.local.example.yaml
└── docs/
    ├── brainstorms/.gitkeep
    ├── plans/.gitkeep
    ├── reviews/.gitkeep
    └── solutions/.gitkeep
```

当项目已经存在 `AGENTS.md` 时，初始化器会保留原文件，并创建 `CE_AGENTS.md` 供人工合并。

## 行为边界

`ce-init` 会：

- 初始化 CE 核心循环：`brainstorm -> plan -> work -> simplify -> code-review -> compound`。
- 创建标准 CE 产物目录并添加 `.gitkeep`。
- 复制官方 `.compound-engineering/config.local.example.yaml`。
- 确保 `.compound-engineering/config.local.yaml` 被 `.gitignore` 忽略。
- 保护已有 `AGENTS.md`、`CE_AGENTS.md` 和 repo-local 配置。

`ce-init` 不会：

- 自动启用 `$lfg`、worktree、功能分支、PR、自动合并或跨模型执行。
- 覆盖项目自己的部署、migration、外部系统、前端或 Git 规则。
- 自动安装、修改或复制官方 CE skills。

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

GitHub Actions 会在 Ubuntu、macOS 和 Windows 上运行对应测试。

## 许可证

本项目采用 [MIT License](LICENSE)。
