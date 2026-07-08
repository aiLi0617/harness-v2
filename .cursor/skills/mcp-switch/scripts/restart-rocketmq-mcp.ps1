#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,

    [string]$ProjectRoot = "",
    [string]$ProjectId = "",
    [string]$WorkspaceConfig = "",
    [switch]$StopOnly
)

$ErrorActionPreference = "Stop"
$SkillRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectRoot) {
    $ProjectRoot = (Get-Item (Join-Path $SkillRoot "..\..\..\..")).FullName
}

$workspacePath = if ($WorkspaceConfig) { $WorkspaceConfig } else { Join-Path $env:USERPROFILE ".cursor\mcp.workspace.json" }
$RestartScript = "D:\mcp\restart-rocketmq-mcp.ps1"

if (-not (Test-Path $workspacePath)) {
    Write-Error "mcp.workspace.json not found: $workspacePath"
}

if (-not (Test-Path $RestartScript)) {
    Write-Warning "restart script missing: $RestartScript"
    exit 0
}

$ws = Get-Content $workspacePath -Raw -Encoding UTF8 | ConvertFrom-Json
$projectEntry = $null
$resolvedProjectId = $ProjectId

if ($resolvedProjectId -and $ws.projects.$resolvedProjectId) {
    $projectEntry = $ws.projects.$resolvedProjectId
} else {
    $normalizedRoot = (Resolve-Path $ProjectRoot).Path -replace '\\', '/'
    foreach ($prop in $ws.projects.PSObject.Properties) {
        $entryPath = [string]$prop.Value.path
        if (-not $entryPath) { continue }
        $normalizedEntry = $entryPath -replace '\\', '/'
        if ($normalizedEntry -ieq $normalizedRoot) {
            $projectEntry = $prop.Value
            $resolvedProjectId = $prop.Name
            break
        }
    }
}

if (-not $projectEntry) {
    Write-Error "Project not found in workspace: root=$ProjectRoot id=$ProjectId workspace=$workspacePath"
}

$profileDoc = $projectEntry.profiles.$Profile
if (-not $profileDoc) {
    Write-Error "Unknown profile '$Profile' for project '$resolvedProjectId' in mcp.workspace.json"
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
    Write-Error "Profile '$Profile' missing ROCKETMQ_NS_ADDR for rocketmq-mcp (project=$resolvedProjectId)"
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
Write-Host "--- rocketmq-mcp restart [$resolvedProjectId / $Profile] ---"
& $RestartScript @restartArgs
Write-Host "---"
