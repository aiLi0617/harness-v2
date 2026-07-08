#Requires -Version 5.1
<#
.SYNOPSIS
  统一切换多个项目的 MCP 环境（dev/sit/pre），合并写入 ~/.cursor/mcp.json

.EXAMPLE
  .\switch-all-mcp-profiles.ps1 sit
  .\switch-all-mcp-profiles.ps1 dev -DryRun
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("dev", "sit", "pre")]
    [string]$Profile,

    [string]$ProjectsRegistry = "",

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
    "--target", "user",
    "--apply-profile-all", $Profile,
    "--workspace-config", $workspacePath
)
if ($ProjectsRegistry) { $argsList += @("--projects-registry", $ProjectsRegistry) }
if ($DryRun) { $argsList += "--dry-run" }

& $python.Source @argsList
if ($LASTEXITCODE -eq 0 -and -not $DryRun) {
    $RocketMqRestart = Join-Path $PSScriptRoot "restart-rocketmq-mcp.ps1"
    $ws = Get-Content $workspacePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $ws.projects.PSObject.Properties) {
        $projectId = $prop.Name
        $entry = $prop.Value
        $root = $entry.path
        if (-not (Test-Path $root)) { continue }
        $profileDoc = $entry.profiles.$Profile
        if (-not $profileDoc) { continue }
        if ("rocketmq-mcp" -notin @($profileDoc.servers)) { continue }
        if (Test-Path $RocketMqRestart) {
            Write-Host ""
            Write-Host "--- rocketmq-mcp restart [$projectId / $Profile] ---"
            & $RocketMqRestart -Profile $Profile -ProjectRoot $root -ProjectId $projectId -WorkspaceConfig $workspacePath
        }
    }
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  请 Reload Window 使配置生效："
    Write-Host "  Ctrl+Shift+P -> 输入 Reload Window -> 回车"
    Write-Host "========================================"
}
exit $LASTEXITCODE
