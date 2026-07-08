#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,

    [string]$ProjectRoot = "",
    [switch]$StopOnly
)

$ErrorActionPreference = "Stop"
$SkillRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item (Join-Path $SkillRoot "..\..\..\..")).FullName
}

$ConfigPath = Join-Path $ProjectRoot ".cursor\mcp.config.json"
$RestartScript = "D:\mcp\restart-rocketmq-mcp.ps1"

if (-not (Test-Path $ConfigPath)) {
    Write-Warning "mcp.config.json not found: $ConfigPath"
    exit 0
}

if (-not (Test-Path $RestartScript)) {
    Write-Warning "restart script missing: $RestartScript"
    exit 0
}

$config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$profileDoc = $config.profiles.$Profile
if (-not $profileDoc) {
    Write-Error "Unknown profile in mcp.config.json: $Profile"
}

$servers = @($profileDoc.servers)
$envMap = @{}
foreach ($prop in $profileDoc.env.PSObject.Properties) {
    $envMap[$prop.Name] = [string]$prop.Value
}

$port = 6868
if ($envMap["ROCKETMQ_MCP_URL"] -match ':(\d+)/') {
    $port = [int]$Matches[1]
}

if ("rocketmq-mcp" -notin $servers) {
    Write-Host "rocketmq-mcp not enabled in profile '$Profile'; stopping local jar on port $port if any"
    & $RestartScript -StopOnly -Port $port
    exit 0
}

$ns = $envMap["ROCKETMQ_NS_ADDR"]
$ak = $envMap["ROCKETMQ_AK"]
$sk = $envMap["ROCKETMQ_SK"]

if (-not $StopOnly -and [string]::IsNullOrWhiteSpace($ns)) {
    Write-Error "Profile '$Profile' missing ROCKETMQ_NS_ADDR for rocketmq-mcp"
}

$restartArgs = @{
    NsAddr  = $ns
    Port    = $port
    Profile = $Profile
}
if (-not [string]::IsNullOrWhiteSpace($ak)) { $restartArgs["Ak"] = $ak }
if (-not [string]::IsNullOrWhiteSpace($sk)) { $restartArgs["Sk"] = $sk }
if ($StopOnly) { $restartArgs["StopOnly"] = $true }

Write-Host ""
Write-Host "--- rocketmq-mcp restart [$Profile] ---"
& $RestartScript @restartArgs
Write-Host "---"
