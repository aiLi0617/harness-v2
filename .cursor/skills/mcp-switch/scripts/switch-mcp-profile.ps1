#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("dev", "sit", "pre")]
    [string]$Profile,

    [ValidateSet("user", "project")]
    [string]$Target = "user",

    [switch]$DryRun,

    [switch]$NoReloadWindow
)

$ErrorActionPreference = "Stop"
$SkillRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = (Get-Item (Join-Path $SkillRoot "..\..\..\..")).FullName
$Configurator = Join-Path $PSScriptRoot "mcp-configurator.py"
. (Join-Path $PSScriptRoot "resolve-mcp-workspace.ps1")
$workspacePath = Resolve-McpWorkspacePath -SkillRoot $SkillRoot

if (-not (Test-Path $workspacePath)) {
    throw "Missing $workspacePath. Ensure mcp-switch/mcp.workspace.json exists (clone repo)."
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
    $ReloadScript = Join-Path $PSScriptRoot "reload-cursor-window.ps1"
    if ($NoReloadWindow) {
        Write-Host ""
        Write-Host "========================================"
        Write-Host "  请 Reload Window 使配置生效："
        Write-Host "  Ctrl+Shift+P -> 输入 Reload Window -> 回车"
        Write-Host "  （或去掉 -NoReloadWindow 以自动触发）"
        Write-Host "========================================"
    }
    elseif (Test-Path $ReloadScript) {
        & $ReloadScript
    }
    else {
        Write-Host ""
        Write-Host "========================================"
        Write-Host "  请 Reload Window 使配置生效："
        Write-Host "  Ctrl+Shift+P -> 输入 Reload Window -> 回车"
        Write-Host "========================================"
    }
}
exit $LASTEXITCODE
