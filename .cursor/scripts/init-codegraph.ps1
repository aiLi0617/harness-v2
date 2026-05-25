<#
.SYNOPSIS
    Initialize CodeGraph: Cursor MCP + project index (.codegraph/).

.PARAMETER ProjectPath
    Business project root. Default: current directory.

.PARAMETER SkipGlobalMcp
    Skip user-level Cursor MCP install.

.PARAMETER SkipGlobalCli
    Skip npm global install; use npx only.

.PARAMETER SkipIndex
    Run init without -i (no initial index).

.PARAMETER ForceReindex
    Force full rebuild when .codegraph/ already exists.

.PARAMETER AcceptGitHooks
    Auto-accept git hooks prompts during init.

.EXAMPLE
    powershell -File init-codegraph.ps1 -ProjectPath D:\Work\Project\Java\my-app -AcceptGitHooks
#>

param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$SkipGlobalMcp,
    [switch]$SkipGlobalCli,
    [switch]$SkipIndex,
    [switch]$ForceReindex,
    [switch]$AcceptGitHooks
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-CodegraphInvoker {
    if (-not $SkipGlobalCli) {
        $cmd = Get-Command codegraph -ErrorAction SilentlyContinue
        if ($cmd) {
            return @{ Command = "codegraph"; PrefixArgs = @() }
        }
        Write-Host "  Installing global @colbymchenry/codegraph ..." -ForegroundColor DarkGray
        npm i -g @colbymchenry/codegraph | Out-Host
        if (Get-Command codegraph -ErrorAction SilentlyContinue) {
            return @{ Command = "codegraph"; PrefixArgs = @() }
        }
    }
    return @{ Command = "npx"; PrefixArgs = @("-y", "@colbymchenry/codegraph") }
}

function Invoke-Codegraph {
    param(
        [hashtable]$Invoker,
        [string[]]$CodegraphArgs
    )
    $allArgs = @($Invoker.PrefixArgs + $CodegraphArgs)
    & $Invoker.Command @allArgs
    if ($LASTEXITCODE -ne 0) {
        throw "codegraph failed: $($Invoker.Command) $($allArgs -join ' ') (exit $LASTEXITCODE)"
    }
}

function Get-McpServerBlock {
    param(
        [object]$Root,
        [string]$Name
    )
    if ($null -eq $Root -or $null -eq $Root.mcpServers) {
        return $null
    }
    return $Root.mcpServers.PSObject.Properties[$Name].Value
}

if (-not (Test-Path $ProjectPath)) {
    Write-Error "Project path not found: $ProjectPath"
    exit 1
}
$ProjectPath = (Resolve-Path $ProjectPath).Path

Write-Host "CodeGraph init" -ForegroundColor Green
Write-Host "  Project: $ProjectPath"

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Error "npx not found. Install Node.js or use CodeGraph install.ps1."
    exit 1
}

$invoker = Get-CodegraphInvoker

if (-not $SkipGlobalMcp) {
    Write-Step "Configure user-level Cursor MCP"
    Invoke-Codegraph -Invoker $invoker -CodegraphArgs @("install", "--target=cursor", "--yes")
    Write-Host "  Restart Cursor after this step." -ForegroundColor DarkGray
}

Write-Step "Check project MCP (codegraph-mcp)"
$mcpJson = Join-Path $ProjectPath ".cursor\mcp.json"
$mcpTemplate = Join-Path $ProjectPath ".cursor\mcp\mcp-template.json"

if (Test-Path $mcpTemplate) {
    $templateObj = Get-Content $mcpTemplate -Raw -Encoding UTF8 | ConvertFrom-Json
    $cgBlock = Get-McpServerBlock -Root $templateObj -Name "codegraph-mcp"
    if ($null -eq $cgBlock) {
        Write-Host "  [WARN] codegraph-mcp missing in mcp-template.json" -ForegroundColor Yellow
    }
    elseif (Test-Path $mcpJson) {
        $mcpObj = Get-Content $mcpJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $existing = Get-McpServerBlock -Root $mcpObj -Name "codegraph-mcp"
        if ($null -eq $existing) {
            if ($null -eq $mcpObj.mcpServers) {
                $mcpObj | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{})
            }
            $mcpObj.mcpServers | Add-Member -NotePropertyName "codegraph-mcp" -NotePropertyValue $cgBlock -Force
            $mcpObj | ConvertTo-Json -Depth 10 | Set-Content $mcpJson -Encoding UTF8
            Write-Host "  [OK] Merged codegraph-mcp into .cursor/mcp.json" -ForegroundColor Green
        }
        else {
            Write-Host "  [OK] .cursor/mcp.json already has codegraph-mcp" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  [WARN] .cursor/mcp.json not found; copy from mcp-template.json first" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  [SKIP] No mcp-template.json (run link-cursor-config first)" -ForegroundColor Yellow
}

Write-Step "Initialize project index"
Push-Location $ProjectPath
try {
    $codegraphDir = Join-Path $ProjectPath ".codegraph"
    if ($ForceReindex -and (Test-Path $codegraphDir)) {
        Write-Host "  Force full reindex ..." -ForegroundColor DarkGray
        Invoke-Codegraph -Invoker $invoker -CodegraphArgs @("index", "--force")
    }
    elseif (Test-Path $codegraphDir) {
        Write-Host "  [SKIP] .codegraph/ exists; running sync (use -ForceReindex to rebuild)" -ForegroundColor Yellow
        Invoke-Codegraph -Invoker $invoker -CodegraphArgs @("sync")
    }
    else {
        $initArgs = @("init")
        if (-not $SkipIndex) {
            $initArgs += "-i"
        }
        if ($AcceptGitHooks) {
            Write-Host "  Auto-accepting git hooks prompts ..." -ForegroundColor DarkGray
            "y`ny`n" | & $invoker.Command @($invoker.PrefixArgs + $initArgs)
            if ($LASTEXITCODE -ne 0) {
                throw "codegraph init failed (exit $LASTEXITCODE)"
            }
        }
        else {
            Invoke-Codegraph -Invoker $invoker -CodegraphArgs $initArgs
            Write-Host "  Tip: accept git hooks when prompted (auto sync on branch switch)." -ForegroundColor DarkGray
        }
    }

    Write-Step "Index status"
    Invoke-Codegraph -Invoker $invoker -CodegraphArgs @("status")
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Done. Restart Cursor and verify .codegraph/ in the project root." -ForegroundColor Green
