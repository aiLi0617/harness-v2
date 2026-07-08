#Requires -Version 5.1
<#
.SYNOPSIS
  新成员 MCP 一键引导：检测依赖 → 生成 workspace → 可选首次 switch

.EXAMPLE
  .\bootstrap-mcp.ps1
  .\bootstrap-mcp.ps1 -BrokerRoot D:\project\zfnjjs-two -CloudRoot D:\project\yunshang-project -B2cRoot D:\project\BToC -SwitchDev
  .\bootstrap-mcp.ps1 -Force
#>
param(
    [string]$BrokerRoot = "",
    [string]$CloudRoot = "",
    [string]$B2cRoot = "",
    [switch]$Force,
    [switch]$SwitchDev,
    [switch]$SkipPrereqCheck
)

$ErrorActionPreference = "Stop"
$InstallRoot = Split-Path -Parent $PSScriptRoot
$SwitchRoot = Join-Path $InstallRoot "..\mcp-switch"
$Configurator = Join-Path $SwitchRoot "scripts\mcp-configurator.py"
$SwitchAll = Join-Path $SwitchRoot "scripts\switch-all-mcp-profiles.ps1"
. (Join-Path $SwitchRoot "scripts\resolve-mcp-workspace.ps1")
$WorkspacePath = Resolve-McpWorkspacePath -SkillRoot $SwitchRoot
$SecretsPath = Resolve-McpWorkspaceSecretsPath -WorkspacePath $WorkspacePath -SkillRoot $SwitchRoot

if (-not $BrokerRoot) {
    $BrokerRoot = (Get-Item (Join-Path $InstallRoot "..\..\..\..")).FullName
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw "Python not found. Install Python 3 first." }

function Test-Cmd([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

Write-Host "=== MCP Bootstrap (mcp-install) ===" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipPrereqCheck) {
    Write-Host "--- 1. 本机依赖检查 ---" -ForegroundColor Yellow
    $checks = @(
        @{ Name = "Python"; Value = $python.Source },
        @{ Name = "Node/npx"; Value = (Test-Cmd "npx") },
        @{ Name = "uv/uvx"; Value = (Test-Cmd "uvx") },
        @{ Name = "Java (rocketmq jar)"; Value = (Test-Cmd "java") },
        @{ Name = "codegraph"; Value = (Test-Cmd "codegraph") }
    )
    foreach ($c in $checks) {
        if ($c.Value) {
            Write-Host "  [OK] $($c.Name): $($c.Value)"
        } else {
            Write-Host "  [!!] $($c.Name): not found"
        }
    }
    Write-Host ""
    Write-Host "  还需手动准备（见 mcp-install/SKILL.md）："
    Write-Host "    - loki-mcp 二进制 → 写入 workspace tools.LOKI_MCP_BIN"
    Write-Host "    - rocketmq-mcp jar → D:\mcp\ 构建后 switch 会自动 restart"
    Write-Host "    - pip install pymysql redis（连通性探测脚本用）"
    Write-Host ""
}

Write-Host "--- 2. 自动检测 tools 路径 ---" -ForegroundColor Yellow
& $python.Source $Configurator --project-root $BrokerRoot --skill-root $SwitchRoot --detect-tools
Write-Host ""

Write-Host "--- 3. 生成 workspace 配置 ---" -ForegroundColor Yellow
$initArgs = @(
    $Configurator,
    "--project-root", $BrokerRoot,
    "--skill-root", $SwitchRoot,
    "--init-workspace",
    "--project-path", "broker=$BrokerRoot"
)
if ($CloudRoot) { $initArgs += @("--project-path", "cloud=$CloudRoot") }
if ($B2cRoot) { $initArgs += @("--project-path", "b2c=$B2cRoot") }
if ($Force) { $initArgs += "--force" }
if ((Test-Path $WorkspacePath) -and -not $Force) {
    Write-Host "  已存在: $WorkspacePath（跳过生成，使用 -Force 覆盖）"
} else {
    & $python.Source @initArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Write-Host ""

Write-Host "--- 4. 待人工填写 ---" -ForegroundColor Yellow
Write-Host "  编辑 workspace: $WorkspacePath"
Write-Host "  编辑 secrets:   $SecretsPath"
Write-Host "  - secrets 文件中将 change-me 替换为团队密钥"
Write-Host "  - 确认 broker/cloud/b2c 的 path 为本机绝对路径"
Write-Host "  - 确认 tools 段路径存在（尤其 LOKI_MCP_BIN）"
Write-Host ""

if ($SwitchDev) {
    if (-not (Test-Path $WorkspacePath)) {
        throw "Workspace not found: $WorkspacePath"
    }
    Write-Host "--- 5. 首次切换 dev ---" -ForegroundColor Yellow
    & $SwitchAll dev
    exit $LASTEXITCODE
}

Write-Host "--- 完成 ---" -ForegroundColor Green
Write-Host "  下一步: 填好 workspace 后执行"
Write-Host "    .cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev"
Write-Host "  然后 Reload Window，运行:"
Write-Host "    python .cursor/.generated/probe-all-projects-dev.py"
