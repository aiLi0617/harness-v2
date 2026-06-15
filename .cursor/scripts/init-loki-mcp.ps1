<#
.SYNOPSIS
    Install Grafana loki-mcp and merge loki-mcp into Cursor MCP config.

.PARAMETER ProjectPath
    Business project root (optional). Merges into .cursor/mcp.json when present.

.PARAMETER LokiUrl
    Default Loki query API URL.

.PARAMETER Mode
    docker | binary | auto (default: auto — Docker first, then Go binary).

.PARAMETER SkipBuild
    Skip image/binary build; only merge MCP config (image/binary must exist).

.EXAMPLE
    powershell -File init-loki-mcp.ps1 -LokiUrl http://192.168.3.25:3100
#>

param(
    [string]$ProjectPath = "",
    [string]$LokiUrl = "http://192.168.3.25:3100",
    [ValidateSet("docker", "binary", "auto")]
    [string]$Mode = "auto",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ImageName = "loki-mcp-server:latest"
$RepoUrl = "https://github.com/grafana/loki-mcp.git"
$RepoTag = "v0.6.0"
$CacheRepo = Join-Path $env:TEMP "loki-mcp"
$BinaryDir = Join-Path $env:LOCALAPPDATA "loki-mcp"
$BinaryPath = Join-Path $BinaryDir "loki-mcp-server.exe"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-DockerReady {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return $false
    }
    docker info 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Ensure-LokiRepo {
    if (-not (Test-Path $CacheRepo)) {
        Write-Host "  Cloning $RepoUrl ($RepoTag) ..."
        git clone --depth 1 --branch $RepoTag $RepoUrl $CacheRepo
    }
}

function Build-DockerImage {
    Ensure-LokiRepo
    Write-Host "  Building Docker image $ImageName ..."
    docker build -t $ImageName $CacheRepo
    if ($LASTEXITCODE -ne 0) {
        throw "docker build failed"
    }
}

function Build-GoBinary {
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        throw "Go not found; install Go or start Docker Desktop"
    }
    Ensure-LokiRepo
    New-Item -ItemType Directory -Force -Path $BinaryDir | Out-Null
    Push-Location $CacheRepo
    try {
        Write-Host "  Building binary -> $BinaryPath ..."
        go build -o $BinaryPath ./cmd/server
        if ($LASTEXITCODE -ne 0) {
            throw "go build failed"
        }
    }
    finally {
        Pop-Location
    }
}

function New-LokiMcpBlock {
    param(
        [string]$InstallMode
    )
    $envBlock = [ordered]@{
        LOKI_URL = $LokiUrl
    }
    if ($InstallMode -eq "docker") {
        return [ordered]@{
            command = "docker"
            args    = @(
                "run", "--rm", "-i",
                "-e", "LOKI_URL",
                "-e", "LOKI_ORG_ID",
                "-e", "LOKI_USERNAME",
                "-e", "LOKI_PASSWORD",
                "-e", "LOKI_TOKEN",
                $ImageName
            )
            env     = $envBlock
        }
    }
    return [ordered]@{
        command = $BinaryPath
        args    = @()
        env     = $envBlock
    }
}

function Merge-McpJson {
    param(
        [string]$Path,
        [hashtable]$Block
    )
    if (-not (Test-Path $Path)) {
        Write-Host "  [SKIP] Not found: $Path" -ForegroundColor Yellow
        return
    }
    $obj = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $obj.mcpServers) {
        $obj | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{})
    }
    $obj.mcpServers | Add-Member -NotePropertyName "loki-mcp" -NotePropertyValue ([pscustomobject]$Block) -Force
    $obj | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    Write-Host "  [OK] Updated loki-mcp in $Path" -ForegroundColor Green
}

Write-Host "Loki MCP init (grafana/loki-mcp)" -ForegroundColor Green
Write-Host "  LOKI_URL: $LokiUrl"

$installMode = $Mode
if ($Mode -eq "auto") {
    $installMode = if (Test-DockerReady) { "docker" } else { "binary" }
    Write-Host "  Mode: auto -> $installMode"
}

if (-not $SkipBuild) {
    Write-Step "Build loki-mcp ($installMode)"
    try {
        if ($installMode -eq "docker") {
            Build-DockerImage
        }
        else {
            Build-GoBinary
        }
    }
    catch {
        if ($Mode -eq "auto" -and $installMode -eq "docker") {
            Write-Host "  Docker build failed, trying Go binary ..." -ForegroundColor Yellow
            $installMode = "binary"
            Build-GoBinary
        }
        else {
            throw
        }
    }
}
else {
    Write-Host "  [SKIP] Build skipped (-SkipBuild)"
    if ($installMode -eq "binary" -and -not (Test-Path $BinaryPath)) {
        Write-Error "Binary not found: $BinaryPath"
    }
}

$block = New-LokiMcpBlock -InstallMode $installMode

Write-Step "Merge Cursor MCP config"
$userMcp = Join-Path $env:USERPROFILE ".cursor\mcp.json"
Merge-McpJson -Path $userMcp -Block $block

if ($ProjectPath -and (Test-Path $ProjectPath)) {
    $projectMcp = Join-Path (Resolve-Path $ProjectPath).Path ".cursor\mcp.json"
    Merge-McpJson -Path $projectMcp -Block $block
}

Write-Host ""
Write-Host "Done. Restart Cursor. Verify MCP panel shows loki-mcp connected." -ForegroundColor Green
Write-Host "Tool: loki_query (LogQL). Optional env: LOKI_ORG_ID, LOKI_TOKEN, LOKI_USERNAME, LOKI_PASSWORD" -ForegroundColor DarkGray
