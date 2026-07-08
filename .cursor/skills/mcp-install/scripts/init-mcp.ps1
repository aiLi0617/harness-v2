#Requires -Version 5.1
<#
.SYNOPSIS
  从 mcp.config.json + mcp-registry 生成/合并 Cursor MCP 配置

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
$Configurator = Join-Path $PSScriptRoot "mcp-configurator.py"

if (-not (Test-Path $Configurator)) {
    throw "Configurator not found: $Configurator"
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw "Python not found. Install Python 3 to run mcp-configurator.py" }

$argsList = @(
    $Configurator,
    "--project-root", $ProjectRoot,
    "--skill-root", $SkillRoot,
    "--target", $Target,
    "--mode", $Mode
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
