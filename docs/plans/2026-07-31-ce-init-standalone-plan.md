---
title: CE Init 独立项目实施计划
status: completed
date: 2026-07-31
---

# CE Init 独立项目实施计划

## 目标

- 将散落在 `~/.codex` 的自定义 CE 初始化器迁移为独立、可版本控制的项目。
- 保持 `ce-init [目录]` 的使用方式，并提供 macOS、Linux 和 Windows 快速安装入口。
- 继续复用已安装的 EveryInc 官方 Compound Engineering 插件，不复制或维护官方 skill。

## 实施单元

1. 将通用规则模板和 Unix 初始化器迁入 `templates/` 与 `bin/`。
2. 实现等价的 PowerShell 初始化器。
3. 实现 GitHub raw 驱动的 Unix 与 Windows 安装器，并支持通过 ref 固定版本。
4. 建立 Unix、Windows 测试和 GitHub Actions 跨平台验证。
5. 本机安装新命令，移除 `~/.codex` 旧副本与 shell alias，验证兼容后推送远端。
6. 跟随官方原生 Codex 插件迁移说明，检测并显式清理旧版 Bun 安装写入的 `COMPOUND CODEX TOOL MAP`；普通项目初始化不得修改 Codex Home。

## 验收

- 新项目能创建 CE 规则、配置示例、产物目录和 `.gitkeep`。
- 已有项目规则不被覆盖，重复运行保持幂等。
- 未安装官方 CE 插件时在修改目标目录前失败并给出明确提示。
- macOS/Linux 安装后 `ce-init` 位于 PATH；Windows 安装后提供 `ce-init.cmd` 并维护用户 PATH。
- Unix 自动化测试通过；Windows 测试由 GitHub Actions 执行。
- `--check` 能报告默认 Codex Home、当前 `CODEX_HOME` 和 profiles 中的旧 tool map；`--cleanup-legacy-tool-map` 只删除完整配对的官方标记区块，残缺标记必须拒绝修改。

## 2026-08-02 迁移能力补充

- Unix 与 PowerShell 已实现全量预检后显式清理；普通初始化不修改 Codex Home，清理命令不依赖 Codex CLI 或插件状态。
- Unix 测试覆盖默认/自定义 Codex Home、profile、LF、CRLF、无末尾换行、空 Home、残缺标记拒绝与跨文件无部分修改。
- `bash -n bin/ce-init install.sh tests/test-unix.sh`、`tests/test-unix.sh` 和真实项目 `--check` 通过；本机没有 PowerShell，GitHub Actions [run 30743958065](https://github.com/ZhcChen/ce-init/actions/runs/30743958065) 的 Ubuntu 与 Windows jobs 均通过，其中 Windows 执行 `tests/ce-init.Tests.ps1`。
