$ErrorActionPreference = 'Stop'

$Repository = if ($env:CE_INIT_REPOSITORY) { $env:CE_INIT_REPOSITORY } else { 'ZhcChen/ce-init' }
$Ref = if ($env:CE_INIT_REF) { $env:CE_INIT_REF } else { 'main' }
$BaseUrl = if ($env:CE_INIT_BASE_URL) { $env:CE_INIT_BASE_URL } else { "https://raw.githubusercontent.com/$Repository/$Ref" }
$InstallRoot = if ($env:CE_INIT_INSTALL_ROOT) { $env:CE_INIT_INSTALL_ROOT } else { Join-Path $env:LOCALAPPDATA 'ce-init' }
$BinDirectory = if ($env:CE_INIT_BIN_DIR) { $env:CE_INIT_BIN_DIR } else { Join-Path $InstallRoot 'bin' }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Force -Path $BinDirectory, (Join-Path $InstallRoot 'templates') | Out-Null

function Download-File([string]$RelativePath, [string]$Destination) {
    $Temporary = "$Destination.tmp.$PID"
    Invoke-WebRequest -Uri "$BaseUrl/$RelativePath" -OutFile $Temporary
    Move-Item -Force $Temporary $Destination
}

Download-File 'bin/ce-init.ps1' (Join-Path $BinDirectory 'ce-init.ps1')
Download-File 'templates/AGENTS.md' (Join-Path $InstallRoot 'templates\AGENTS.md')
Download-File 'VERSION' (Join-Path $InstallRoot 'VERSION')

$Wrapper = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ce-init.ps1" %*
'@
[IO.File]::WriteAllText((Join-Path $BinDirectory 'ce-init.cmd'), $Wrapper, [Text.ASCIIEncoding]::new())

$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$PathEntries = @($UserPath -split ';' | Where-Object { $_ })
if ($PathEntries -notcontains $BinDirectory) {
    $NewUserPath = (@($PathEntries) + $BinDirectory) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $NewUserPath, 'User')
}
if (($env:Path -split ';') -notcontains $BinDirectory) {
    $env:Path = "$BinDirectory;$env:Path"
}

Write-Output "ce-init installed at: $InstallRoot"
Write-Output "Command entry point: $(Join-Path $BinDirectory 'ce-init.cmd')"
Write-Output 'Open a new terminal, run ce-init --version, then run ce-init to initialize a project.'
