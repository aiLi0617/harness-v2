#Requires -Version 5.1
<#
.SYNOPSIS
  显示当前工作区项目在 ~/.cursor/mcp.json 中对应的 MCP 工具名

.EXAMPLE
  .\show-project-mcp.ps1
  .\show-project-mcp.ps1 -ProjectRoot D:\project\zfnjjs-two
#>
param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"
$SkillRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item (Join-Path $SkillRoot "..\..\..\..")).FullName
}
$Configurator = Join-Path $PSScriptRoot "mcp-configurator.py"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw "Python not found" }

& $python.Source @(
    $Configurator,
    "--project-root", $ProjectRoot,
    "--skill-root", $SkillRoot,
    "--show-project-mcp"
)
exit $LASTEXITCODE
