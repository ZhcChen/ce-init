# CE Init 项目规则

## 工作流
- 本项目使用 Compound Engineering，默认循环为 `brainstorm -> plan -> work -> simplify -> code-review -> compound`。
- 明确的小改动可以直接实施并做聚焦验证；跨平台行为调整需要先更新或确认 `docs/plans/` 中的计划。
- 项目规则优先于 CE skill 默认行为，不默认使用 worktree、功能分支、PR、自动合并或跨模型执行。

## 实现约束
- `bin/ce-init` 与 `bin/ce-init.ps1` 必须保持行为一致。
- Unix 实现兼容当前 macOS Bash 和常见 Linux Bash；Windows 实现兼容 Windows PowerShell 5.1 与 PowerShell 7。
- 运行时不引入 Node、Python或第三方包依赖。
- 初始化不得覆盖已有 `AGENTS.md`、定制的 `CE_AGENTS.md` 或 repo-local CE 配置。
- `templates/AGENTS.md` 是分发给目标项目的通用模板，不得加入某个业务项目专属规则。
- 安装器默认可从 GitHub raw `main` 获取文件，同时必须允许通过 ref 固定版本。

## 验证
- Unix 改动运行 `bash -n bin/ce-init install.sh tests/test-unix.sh` 和 `tests/test-unix.sh`。
- PowerShell 改动运行 `tests/ce-init.Tests.ps1`；本机没有 PowerShell 时至少完成静态审查，并依赖 Windows CI 做最终验证。
- 提交前执行 `git diff --check`，只暂存当前任务文件。

## Git
- 默认直接在 `main` 开发，按可独立解释的小闭环提交并推送。
- 提交信息使用简体中文和 Conventional Commits 前缀。
- 不强推，不绕过 Git hooks。
