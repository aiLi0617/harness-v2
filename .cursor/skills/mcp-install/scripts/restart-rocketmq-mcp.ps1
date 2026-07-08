#Requires -Version 5.1
<#
.SYNOPSIS
  转发到 mcp-switch/scripts/restart-rocketmq-mcp.ps1（兼容旧路径）
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,

    [string]$ProjectRoot = "",
    [switch]$StopOnly
)

$ErrorActionPreference = "Stop"
$TargetScript = Join-Path $PSScriptRoot "..\..\mcp-switch\scripts\restart-rocketmq-mcp.ps1"
if (-not (Test-Path $TargetScript)) {
    throw "Switch script not found: $TargetScript"
}

$params = @{
    Profile = $Profile
}
if ($ProjectRoot) { $params.ProjectRoot = $ProjectRoot }
if ($StopOnly) { $params.StopOnly = $true }

& $TargetScript @params
exit $LASTEXITCODE
