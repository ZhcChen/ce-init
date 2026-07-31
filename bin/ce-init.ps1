$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("Error: $Message")
    exit 1
}

function Show-Usage {
    @'
Usage: ce-init [options] [project-directory]

Initialize a project with the Compound Engineering workflow.
The project directory defaults to the current directory.

Options:
  --check    Check the target project without modifying files
  --help     Show help
  --version  Show version
'@
}

$CheckOnly = $false
$TargetDirectory = $null

foreach ($Argument in $args) {
    switch ($Argument) {
        '--check' { $CheckOnly = $true; continue }
        '--help' { Show-Usage; exit 0 }
        '-h' { Show-Usage; exit 0 }
        '--version' {
            $VersionFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'VERSION'
            if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { 'development' }
            exit 0
        }
        default {
            if ($Argument.StartsWith('--')) { Fail "Unknown option: $Argument" }
            if ($null -ne $TargetDirectory) { Fail 'Only one project directory can be specified' }
            $TargetDirectory = $Argument
        }
    }
}

if ($null -eq $TargetDirectory) { $TargetDirectory = (Get-Location).Path }

if ($env:CE_INIT_TEMPLATE) {
    $Template = $env:CE_INIT_TEMPLATE
} else {
    $Template = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\AGENTS.md'
}
if (-not (Test-Path $Template -PathType Leaf)) { Fail "CE rules template not found: $Template" }

$CodexCommand = if ($env:CODEX_BIN) { $env:CODEX_BIN } else { (Get-Command codex -ErrorAction SilentlyContinue).Source }
if (-not $CodexCommand) { Fail 'Codex CLI not found. Install Codex first.' }

$PluginLine = (& $CodexCommand plugin list 2>$null | Where-Object {
    $_ -match '^compound-engineering@compound-engineering-plugin\s+' -and $_ -match 'installed, enabled'
} | Select-Object -First 1)
if (-not $PluginLine) {
    Fail 'The official Compound Engineering plugin is not installed and enabled. Run: codex plugin marketplace add EveryInc/compound-engineering-plugin; codex plugin add compound-engineering@compound-engineering-plugin'
}

$PluginFields = @($PluginLine -split '\s{2,}' | Where-Object { $_ })
$PluginRoot = $PluginFields[-1].Trim()
$ConfigTemplate = Join-Path $PluginRoot 'skills\ce-setup\references\config-template.yaml'
if (-not (Test-Path $ConfigTemplate -PathType Leaf)) { Fail "Official CE config template not found: $ConfigTemplate" }

if ($CheckOnly) {
    if (-not (Test-Path $TargetDirectory -PathType Container)) { Fail "Project directory not found: $TargetDirectory" }
    $TargetDirectory = (Resolve-Path $TargetDirectory).Path
    $Issues = 0
    if (-not (Test-Path (Join-Path $TargetDirectory 'AGENTS.md'))) { Write-Output 'Missing: AGENTS.md'; $Issues = 1 }
    foreach ($ArtifactDirectory in @('brainstorms', 'plans', 'reviews', 'solutions')) {
        if (-not (Test-Path (Join-Path $TargetDirectory "docs\$ArtifactDirectory\.gitkeep"))) {
            Write-Output "Missing: docs/$ArtifactDirectory/.gitkeep"
            $Issues = 1
        }
    }
    $ConfigExample = Join-Path $TargetDirectory '.compound-engineering\config.local.example.yaml'
    if (-not (Test-Path $ConfigExample)) {
        Write-Output 'Missing: .compound-engineering/config.local.example.yaml'
        $Issues = 1
    } elseif ((Get-FileHash $ConfigTemplate).Hash -ne (Get-FileHash $ConfigExample).Hash) {
        Write-Output 'Outdated: .compound-engineering/config.local.example.yaml (run $ce-setup to refresh)'
        $Issues = 1
    }
    $GitIgnore = Join-Path $TargetDirectory '.gitignore'
    $GitIgnoreContent = if (Test-Path $GitIgnore) { Get-Content $GitIgnore -Raw } else { '' }
    if ($GitIgnoreContent -notmatch '(?m)^\.compound-engineering/(config\.local\.yaml|\*\.local\.yaml)$') {
        Write-Output 'Missing: CE local config rule in .gitignore'
        $Issues = 1
    }
    if ($Issues -eq 0) { Write-Output "CE initialization is healthy: $TargetDirectory" }
    exit $Issues
}

New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null
$TargetDirectory = (Resolve-Path $TargetDirectory).Path
$ConfigDirectory = Join-Path $TargetDirectory '.compound-engineering'

foreach ($Directory in @(
    (Join-Path $TargetDirectory 'docs\brainstorms'),
    (Join-Path $TargetDirectory 'docs\plans'),
    (Join-Path $TargetDirectory 'docs\reviews'),
    (Join-Path $TargetDirectory 'docs\solutions'),
    $ConfigDirectory
)) {
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
}

foreach ($ArtifactDirectory in @('brainstorms', 'plans', 'reviews', 'solutions')) {
    $KeepFile = Join-Path $TargetDirectory "docs\$ArtifactDirectory\.gitkeep"
    if (-not (Test-Path $KeepFile)) { New-Item -ItemType File -Path $KeepFile | Out-Null }
}

$ConfigExample = Join-Path $ConfigDirectory 'config.local.example.yaml'
if (-not (Test-Path $ConfigExample)) {
    Copy-Item $ConfigTemplate $ConfigExample
    Write-Output 'Created: .compound-engineering/config.local.example.yaml'
} elseif ((Get-FileHash $ConfigTemplate).Hash -ne (Get-FileHash $ConfigExample).Hash) {
    Write-Output 'Kept the existing CE config example; run $ce-setup to check and refresh it'
}

$GitIgnore = Join-Path $TargetDirectory '.gitignore'
$GitIgnoreContent = if (Test-Path $GitIgnore) { Get-Content $GitIgnore -Raw } else { '' }
if ($GitIgnoreContent -notmatch '(?m)^\.compound-engineering/(config\.local\.yaml|\*\.local\.yaml)$') {
    $Prefix = if ($GitIgnoreContent.Length -gt 0 -and -not $GitIgnoreContent.EndsWith("`n")) { "`r`n" } else { '' }
    [IO.File]::AppendAllText($GitIgnore, "$Prefix.compound-engineering/config.local.yaml`r`n", [Text.UTF8Encoding]::new($false))
    Write-Output 'Updated: .gitignore'
}

$AgentsFile = Join-Path $TargetDirectory 'AGENTS.md'
$CeAgentsFile = Join-Path $TargetDirectory 'CE_AGENTS.md'
if (-not (Test-Path $AgentsFile)) {
    Copy-Item $Template $AgentsFile
    Write-Output "Created AGENTS.md from the CE template: $TargetDirectory"
} elseif (-not (Test-Path $CeAgentsFile)) {
    Copy-Item $Template $CeAgentsFile
    Write-Output 'Preserved AGENTS.md and created CE_AGENTS.md for manual merge'
} elseif ((Get-FileHash $Template).Hash -eq (Get-FileHash $CeAgentsFile).Hash) {
    Write-Output 'Preserved AGENTS.md; CE_AGENTS.md is current'
} else {
    Write-Output "Preserved AGENTS.md and CE_AGENTS.md; merge manually from: $Template"
}

Write-Output "Created CE artifact directories and .gitkeep files: $TargetDirectory\docs"
Write-Output 'Next: review the generated files, then run $ce-setup in Codex'
