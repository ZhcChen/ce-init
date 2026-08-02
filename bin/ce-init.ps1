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
  --check                    Check the project and legacy CE tool map without modifying files
  --cleanup-legacy-tool-map  Explicitly remove the obsolete CE tool map from Codex Home
  --help                     Show help
  --version                  Show version
'@
}

$CheckOnly = $false
$CleanupLegacyToolMap = $false
$TargetDirectory = $null
$ToolMapBegin = '<!-- BEGIN COMPOUND CODEX TOOL MAP -->'
$ToolMapEnd = '<!-- END COMPOUND CODEX TOOL MAP -->'

function Get-CodexAgentsFiles {
    $DefaultCodexHome = Join-Path $HOME '.codex'
    $ActiveCodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { $DefaultCodexHome }
    $Candidates = [System.Collections.Generic.List[string]]::new()
    $Candidates.Add((Join-Path $ActiveCodexHome 'AGENTS.md'))
    $Candidates.Add((Join-Path $DefaultCodexHome 'AGENTS.md'))
    foreach ($ProfilesRoot in @((Join-Path $ActiveCodexHome 'profiles'), (Join-Path $DefaultCodexHome 'profiles'))) {
        if (Test-Path $ProfilesRoot -PathType Container) {
            Get-ChildItem $ProfilesRoot -Directory | ForEach-Object {
                $Candidates.Add((Join-Path $_.FullName 'AGENTS.md'))
            }
        }
    }
    $Seen = @{}
    foreach ($Candidate in $Candidates) {
        $FullPath = [IO.Path]::GetFullPath($Candidate)
        $Key = $FullPath.ToLowerInvariant()
        if (-not $Seen.ContainsKey($Key) -and (Test-Path $FullPath -PathType Leaf)) {
            $Seen[$Key] = $true
            $FullPath
        }
    }
}

function Get-LegacyToolMapState([string]$Path) {
    $Inside = $false
    $Found = $false
    $Invalid = $false
    foreach ($Line in [IO.File]::ReadAllLines($Path)) {
        if ($Line -ceq $ToolMapBegin) {
            if ($Inside) { $Invalid = $true }
            $Inside = $true
            $Found = $true
        } elseif ($Line -ceq $ToolMapEnd) {
            if (-not $Inside) { $Invalid = $true }
            $Inside = $false
        }
    }
    if ($Invalid -or $Inside) { return 'invalid' }
    if ($Found) { return 'legacy' }
    return 'none'
}

function Remove-LegacyToolMaps {
    $Cleaned = $false
    $AgentsFiles = @(Get-CodexAgentsFiles)
    foreach ($AgentsFile in $AgentsFiles) {
        $State = Get-LegacyToolMapState $AgentsFile
        if ($State -eq 'invalid') { Fail "Legacy CE tool map markers are incomplete; file was not changed: $AgentsFile" }
        if ($State -eq 'legacy' -and ((Get-Item $AgentsFile).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Fail "Legacy CE tool map is in a symbolic link; file was not changed: $AgentsFile"
        }
    }
    foreach ($AgentsFile in $AgentsFiles) {
        if ((Get-LegacyToolMapState $AgentsFile) -eq 'none') { continue }
        $Content = [IO.File]::ReadAllText($AgentsFile)
        $Pattern = '(?ms)^' + [Regex]::Escape($ToolMapBegin) + '\r?\n.*?^' + [Regex]::Escape($ToolMapEnd) + '(?:\r?\n|$)'
        $Updated = [Regex]::Replace($Content, $Pattern, '')
        $Temporary = "$AgentsFile.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
        try {
            [IO.File]::WriteAllText($Temporary, $Updated, [Text.UTF8Encoding]::new($false))
            Move-Item -Force $Temporary $AgentsFile
        } finally {
            Remove-Item -Force $Temporary -ErrorAction SilentlyContinue
        }
        Write-Output "Removed legacy CE tool map: $AgentsFile"
        $Cleaned = $true
    }
    if (-not $Cleaned) { Write-Output 'No legacy CE tool map found' }
}

foreach ($Argument in $args) {
    switch ($Argument) {
        '--check' { $CheckOnly = $true; continue }
        '--cleanup-legacy-tool-map' { $CleanupLegacyToolMap = $true; continue }
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

if ($CleanupLegacyToolMap) {
    if ($CheckOnly) { Fail '--check and --cleanup-legacy-tool-map cannot be used together' }
    if ($null -ne $TargetDirectory) { Fail '--cleanup-legacy-tool-map does not accept a project directory' }
    Remove-LegacyToolMaps
    exit 0
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
    foreach ($AgentsFile in Get-CodexAgentsFiles) {
        $State = Get-LegacyToolMapState $AgentsFile
        if ($State -eq 'legacy') {
            Write-Output "Obsolete: legacy CE tool map: $AgentsFile (run ce-init --cleanup-legacy-tool-map)"
            $Issues = 1
        } elseif ($State -eq 'invalid') {
            Write-Output "Error: incomplete legacy CE tool map markers: $AgentsFile"
            $Issues = 1
        }
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
