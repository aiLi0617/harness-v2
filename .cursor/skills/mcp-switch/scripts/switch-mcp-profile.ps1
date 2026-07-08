#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("dev", "sit", "pre")]
    [string]$Profile,

    [ValidateSet("user", "project")]
    [string]$Target = "user",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$SkillRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = (Get-Item (Join-Path $SkillRoot "..\..\..\..")).FullName
$Configurator = Join-Path $PSScriptRoot "mcp-configurator.py"
$workspacePath = Join-Path $env:USERPROFILE ".cursor\mcp.workspace.json"

if (-not (Test-Path $workspacePath)) {
    throw "Missing $workspacePath. Copy mcp-switch/mcp.workspace.example.json to ~/.cursor/mcp.workspace.json and edit."
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw "Python not found" }

$argsList = @(
    $Configurator,
    "--project-root", $ProjectRoot,
    "--skill-root", $SkillRoot,
    "--target", $Target,
    "--apply-profile", $Profile,
    "--workspace-config", $workspacePath
)
if ($DryRun) { $argsList += "--dry-run" }

& $python.Source @argsList
if ($LASTEXITCODE -eq 0 -and -not $DryRun) {
    $RocketMqRestart = Join-Path $PSScriptRoot "restart-rocketmq-mcp.ps1"
    if (Test-Path $RocketMqRestart) {
        & $RocketMqRestart -Profile $Profile -ProjectRoot $ProjectRoot -WorkspaceConfig $workspacePath
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  请 Reload Window 使配置生效："
    Write-Host "  Ctrl+Shift+P -> 输入 Reload Window -> 回车"
    Write-Host "========================================"
}
exit $LASTEXITCODE
