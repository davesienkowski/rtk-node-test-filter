# Installer for the rtk node --test filter pack (Windows PowerShell).
# Safe to run repeatedly (idempotent).
[CmdletBinding()]
param(
  [switch]$InstallRtk,
  [switch]$Global,
  [string]$Project,          # path; pass to install project-local
  [switch]$Alias,
  [switch]$Hook,
  [switch]$All,
  [switch]$Yes,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackFilters = Join-Path $ScriptDir 'filters.toml'
$HookScript  = Join-Path $ScriptDir 'hook/rtk-node-test-hook.mjs'
$Merge       = Join-Path $ScriptDir 'lib/merge.mjs'

if ($Help) {
@"
rtk node --test filter pack installer (Windows)

Usage: ./install.ps1 [-InstallRtk] [-Global] [-Project <dir>] [-Alias] [-Hook] [-All] [-Yes]
  -InstallRtk   Install rtk if missing (winget/scoop/cargo, else points to releases)
  -Global       Install the filter into user-global rtk config (all projects)
  -Project <d>  Install as project-local .rtk\filters.toml in <d> + rtk trust
  -Alias        Add an 'ntest' function (ntest = rtk node --test) to your PowerShell profile
  -Hook         Install the optional Claude Code PreToolUse hook
  -All          Shorthand for -Global -Alias
Requires: node, rtk.
"@
  exit 0
}

if ($All) { $Global = $true; $Alias = $true }

function Confirm-Step($msg) {
  if ($Yes) { return $true }
  $a = Read-Host "$msg [y/N]"
  return $a -match '^(y|yes)$'
}

# Interactive defaults if nothing was requested
if (-not ($InstallRtk -or $Global -or $Project -or $Alias -or $Hook)) {
  if (Confirm-Step 'Install rtk if missing?')                          { $InstallRtk = $true }
  if (Confirm-Step 'Install filter user-globally (recommended)?')      { $Global = $true }
  if (Confirm-Step "Also add the 'ntest' function?")                   { $Alias = $true }
  if (Confirm-Step 'Install the optional Claude Code auto-rewrite hook?') { $Hook = $true }
}

function Get-RtkConfigDir { Join-Path $env:APPDATA 'rtk' }

function Install-Rtk {
  if (Get-Command rtk -ErrorAction SilentlyContinue) { Write-Host "rtk already installed."; return }
  if (Get-Command winget -ErrorAction SilentlyContinue) { winget install rtk-ai.rtk; return }
  if (Get-Command scoop  -ErrorAction SilentlyContinue) { scoop install rtk; return }
  if (Get-Command cargo  -ErrorAction SilentlyContinue) { cargo install --git https://github.com/rtk-ai/rtk rtk; return }
  Write-Warning "No package manager found. Download rtk.exe from https://github.com/rtk-ai/rtk/releases and put it on PATH."
}

function Require-Rtk {
  if (-not (Get-Command rtk -ErrorAction SilentlyContinue)) {
    throw "rtk is not on PATH. Re-run with -InstallRtk, or see README.md."
  }
}

if ($InstallRtk) { Install-Rtk }

if ($Global) {
  Require-Rtk
  $dst = Join-Path (Get-RtkConfigDir) 'filters.toml'
  node $Merge filters-global $PackFilters $dst
  Write-Host "User-global filter installed (applies to all projects; no 'rtk trust' needed)."
}

if ($Project) {
  Require-Rtk
  $dir = Resolve-Path $Project
  New-Item -ItemType Directory -Force -Path (Join-Path $dir '.rtk') | Out-Null
  Copy-Item $PackFilters (Join-Path $dir '.rtk/filters.toml') -Force
  Push-Location $dir; try { rtk trust } finally { Pop-Location }
  Write-Host "Project filter installed and trusted in $dir."
}

if ($Alias) {
  $profilePath = $PROFILE
  $fn = "function ntest { rtk node --test @args }"
  New-Item -ItemType File -Force -Path $profilePath | Out-Null
  if (Select-String -Path $profilePath -SimpleMatch 'function ntest' -Quiet) {
    Write-Host "ntest function already present in $profilePath"
  } else {
    Add-Content $profilePath "`n# rtk node --test filter pack`n$fn"
    Write-Host "added 'ntest' function to $profilePath (restart PowerShell)"
  }
}

if ($Hook) {
  $settings = Join-Path $env:USERPROFILE '.claude/settings.json'
  node $Merge settings-hook $settings $HookScript
  Write-Host "Optional hook installed. Restart Claude Code so it reloads hooks."
}

Write-Host "Done. Verify with: rtk verify --require-all   (then try: rtk node --test <file>)"
