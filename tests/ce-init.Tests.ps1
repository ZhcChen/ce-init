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

    & (Join-Path $Root 'bin\ce-init.ps1') $Target | Out-Null
    Assert-True (Test-Path (Join-Path $Target 'AGENTS.md')) 'AGENTS.md 不存在'
    foreach ($Directory in @('brainstorms', 'plans', 'reviews', 'solutions')) {
        Assert-True (Test-Path (Join-Path $Target "docs\$Directory\.gitkeep")) "$Directory/.gitkeep 不存在"
    }
    & (Join-Path $Root 'bin\ce-init.ps1') --check $Target | Out-Null

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
    Remove-Item -Recurse -Force $TestRoot -ErrorAction SilentlyContinue
}
