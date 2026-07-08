#Requires -Version 5.1
<#
.SYNOPSIS
  转发到 mcp-switch/scripts/show-project-mcp.ps1（兼容旧路径）
#>
param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"
$TargetScript = Join-Path $PSScriptRoot "..\..\mcp-switch\scripts\show-project-mcp.ps1"
if (-not (Test-Path $TargetScript)) {
    throw "Switch script not found: $TargetScript"
}

$params = @{}
if ($ProjectRoot) { $params.ProjectRoot = $ProjectRoot }

& $TargetScript @params
exit $LASTEXITCODE
