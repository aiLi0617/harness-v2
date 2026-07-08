#Requires -Version 5.1
<#
.SYNOPSIS
  从 mcp.workspace.json + mcp-registry 生成/合并 Cursor MCP 配置

.EXAMPLE
  .\init-mcp.ps1 -ListProfiles
  .\init-mcp.ps1 -Profile dev
  # 日常切换环境请用 mcp-switch skill：switch-mcp-profile.ps1 sit
#>
param(
    [ValidateSet("user", "project")]
    [string]$Target = "user",

    [ValidateSet("single", "unified")]
    [string]$Mode = "single",

    [string]$Profile = "",
    [string[]]$Servers = @(),
    [switch]$DryRun,
    [switch]$Force,
    [switch]$ListProfiles
)

$ErrorActionPreference = "Stop"
$SkillRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = (Get-Item (Join-Path $SkillRoot "..\..\..\..")).FullName
$Configurator = Join-Path $SkillRoot "..\mcp-switch\scripts\mcp-configurator.py"
$workspacePath = Join-Path $env:USERPROFILE ".cursor\mcp.workspace.json"

if (-not (Test-Path $Configurator)) {
    throw "Configurator not found: $Configurator"
}

if (-not (Test-Path $workspacePath)) {
    throw "Missing $workspacePath. Copy mcp-switch/mcp.workspace.example.json to ~/.cursor/mcp.workspace.json and edit."
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw "Python not found. Install Python 3 to run mcp-configurator.py" }

$argsList = @(
    $Configurator,
    "--project-root", $ProjectRoot,
    "--skill-root", (Join-Path $SkillRoot "..\mcp-switch"),
    "--target", $Target,
    "--mode", $Mode,
    "--workspace-config", $workspacePath
)

if ($ListProfiles) {
    $argsList += "--list-profiles"
    & $python.Source @argsList
    exit $LASTEXITCODE
}

if ($Profile) { $argsList += @("--profile", $Profile) }
if ($Servers.Count -gt 0) { $argsList += @("--servers", ($Servers -join ",")) }
if ($DryRun) { $argsList += "--dry-run" }
if ($Force) { $argsList += "--force" }

& $python.Source @argsList
exit $LASTEXITCODE
