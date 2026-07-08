#Requires -Version 5.1
<#
.SYNOPSIS
  转发到 mcp-switch/scripts/switch-all-mcp-profiles.ps1（兼容旧路径）
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("dev", "sit", "pre")]
    [string]$Profile,

    [string]$ProjectsRegistry = "",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$TargetScript = Join-Path $PSScriptRoot "..\..\mcp-switch\scripts\switch-all-mcp-profiles.ps1"
if (-not (Test-Path $TargetScript)) {
    throw "Switch script not found: $TargetScript"
}

$params = @{
    Profile = $Profile
}
if ($ProjectsRegistry) { $params.ProjectsRegistry = $ProjectsRegistry }
if ($DryRun) { $params.DryRun = $true }

& $TargetScript @params
exit $LASTEXITCODE
