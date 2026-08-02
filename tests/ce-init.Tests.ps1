$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}

$Root = Split-Path $PSScriptRoot -Parent
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) "ce-init-test-$PID"
$PluginRoot = Join-Path $TestRoot 'plugin with spaces'
$ConfigDirectory = Join-Path $PluginRoot 'skills\ce-setup\references'
$FakeBin = Join-Path $TestRoot 'fake-bin'
$Target = Join-Path $TestRoot 'target'

try {
    New-Item -ItemType Directory -Force -Path $ConfigDirectory, $FakeBin | Out-Null
    [IO.File]::WriteAllText((Join-Path $ConfigDirectory 'config-template.yaml'), "docs_root: docs`r`n")

    $FakeCodex = @"
@echo off
echo compound-engineering@compound-engineering-plugin  installed, enabled  3.21.0  $PluginRoot
exit /b 0
"@
    [IO.File]::WriteAllText((Join-Path $FakeBin 'codex.cmd'), $FakeCodex, [Text.ASCIIEncoding]::new())
    $env:CODEX_BIN = Join-Path $FakeBin 'codex.cmd'
    $PowerShellExe = (Get-Process -Id $PID).Path
    $CeInitScript = Join-Path $Root 'bin\ce-init.ps1'

    & $CeInitScript $Target | Out-Null
    Assert-True (Test-Path (Join-Path $Target 'AGENTS.md')) 'AGENTS.md 不存在'
    foreach ($Directory in @('brainstorms', 'plans', 'reviews', 'solutions')) {
        Assert-True (Test-Path (Join-Path $Target "docs\$Directory\.gitkeep")) "$Directory/.gitkeep 不存在"
    }
    $HealthyCheckOutput = @(& $PowerShellExe -NoProfile -File $CeInitScript --check $Target 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) "健康项目的 --check 应成功：$($HealthyCheckOutput -join ' | ')"

    $CodexHome = Join-Path $TestRoot 'codex-home'
    $DefaultAgents = Join-Path $CodexHome 'AGENTS.md'
    $ProfileAgents = Join-Path $CodexHome 'profiles\work\AGENTS.md'
    New-Item -ItemType Directory -Force -Path (Split-Path $DefaultAgents), (Split-Path $ProfileAgents) | Out-Null
    $LegacyContent = @'
# Keep rule
<!-- BEGIN COMPOUND CODEX TOOL MAP -->
- obsolete mapping
<!-- END COMPOUND CODEX TOOL MAP -->
# Following rule
'@
    [IO.File]::WriteAllText($DefaultAgents, $LegacyContent, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($ProfileAgents, $LegacyContent, [Text.UTF8Encoding]::new($false))
    $env:CODEX_HOME = $CodexHome

    & $PowerShellExe -NoProfile -File $CeInitScript --check $Target | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) '--check 未报告旧版 tool map'

    $env:CODEX_BIN = Join-Path $FakeBin 'missing-codex.cmd'
    & $PowerShellExe -NoProfile -File $CeInitScript --cleanup-legacy-tool-map | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) '显式 tool map 清理失败'
    foreach ($AgentsFile in @($DefaultAgents, $ProfileAgents)) {
        $Content = [IO.File]::ReadAllText($AgentsFile)
        Assert-True ($Content.Contains('# Keep rule')) "清理破坏了前置规则：$AgentsFile"
        Assert-True ($Content.Contains('# Following rule')) "清理破坏了后续规则：$AgentsFile"
        Assert-True (-not $Content.Contains('COMPOUND CODEX TOOL MAP')) "旧版 tool map 未清理：$AgentsFile"
    }

    $ValidButMustRemain = "# Earlier file`r`n<!-- BEGIN COMPOUND CODEX TOOL MAP -->`r`n- valid but must remain`r`n<!-- END COMPOUND CODEX TOOL MAP -->`r`n"
    $Malformed = "# Malformed file`r`n<!-- BEGIN COMPOUND CODEX TOOL MAP -->`r`n- missing end`r`n"
    [IO.File]::WriteAllText($DefaultAgents, $ValidButMustRemain, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($ProfileAgents, $Malformed, [Text.UTF8Encoding]::new($false))
    & $PowerShellExe -NoProfile -File $CeInitScript --cleanup-legacy-tool-map 2>$null | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) '残缺 tool map 标记应拒绝清理'
    Assert-True ([IO.File]::ReadAllText($DefaultAgents) -eq $ValidButMustRemain) '预检失败前已有文件被部分清理'
    Assert-True ([IO.File]::ReadAllText($ProfileAgents) -eq $Malformed) '残缺标记文件被修改'
    Remove-Item $DefaultAgents, $ProfileAgents
    $env:CODEX_BIN = Join-Path $FakeBin 'codex.cmd'

    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'install.ps1'), [ref]$Tokens, [ref]$Errors) | Out-Null
    Assert-True ($Errors.Count -eq 0) 'install.ps1 存在语法错误'

    if ($env:GITHUB_SHA -and $env:GITHUB_REPOSITORY) {
        $InstallRoot = Join-Path $TestRoot 'installed'
        $env:CE_INIT_BASE_URL = "https://raw.githubusercontent.com/$env:GITHUB_REPOSITORY/$env:GITHUB_SHA"
        $env:CE_INIT_INSTALL_ROOT = $InstallRoot
        $env:CE_INIT_BIN_DIR = Join-Path $InstallRoot 'bin'
        $env:CE_INIT_SKIP_PATH_UPDATE = '1'
        & (Join-Path $Root 'install.ps1') | Out-Null
        Assert-True (Test-Path (Join-Path $InstallRoot 'bin\ce-init.cmd')) 'Windows 安装器未创建 ce-init.cmd'
        Assert-True (Test-Path (Join-Path $InstallRoot 'templates\AGENTS.md')) 'Windows 安装器未安装模板'
        $InstalledVersion = & (Join-Path $InstallRoot 'bin\ce-init.ps1') --version
        Assert-True ($InstalledVersion -eq (Get-Content (Join-Path $Root 'VERSION') -Raw).Trim()) 'Windows 安装版本不匹配'
    }

    Write-Output 'PASS: Windows ce-init tests'
} finally {
    Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $TestRoot -ErrorAction SilentlyContinue
}
