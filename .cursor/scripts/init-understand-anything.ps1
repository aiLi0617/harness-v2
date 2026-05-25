<#
.SYNOPSIS
    Install Lum1104/Understand-Anything for Cursor (global clone + optional project wiring).

.PARAMETER ProjectPath
    Business project root. Creates junctions for Cursor plugin auto-discovery.

.PARAMETER SkipBuild
    Skip pnpm build (plugin must already be built in the global checkout).

.PARAMETER Force
    Replace existing junctions at the project root.

.EXAMPLE
    powershell -File init-understand-anything.ps1 -ProjectPath D:\Work\Project\Java\my-app
#>

param(
    [string]$ProjectPath = "",
    [switch]$SkipBuild,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RepoUrl = "https://github.com/Lum1104/Understand-Anything.git"
$RepoDir = Join-Path $env:USERPROFILE ".understand-anything\repo"
$PluginLink = Join-Path $env:USERPROFILE ".understand-anything-plugin"
$PluginDir = Join-Path $RepoDir "understand-anything-plugin"
$CursorPluginDir = Join-Path $RepoDir ".cursor-plugin"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-IsReparse([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return ($item.LinkType -eq "Junction" -or $item.LinkType -eq "SymbolicLink")
}

function New-JunctionSafe {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [switch]$Replace
    )
    if (-not (Test-Path $TargetPath)) {
        throw "Target not found: $TargetPath"
    }
    if (Test-Path $LinkPath) {
        if (Test-IsReparse $LinkPath) {
            if ($Replace) {
                (Get-Item -LiteralPath $LinkPath -Force).Delete()
            }
            else {
                Write-Host "  [OK] Junction exists: $LinkPath" -ForegroundColor Green
                return
            }
        }
        else {
            throw "Refusing to overwrite real path: $LinkPath (use -Force)"
        }
    }
    New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
    Write-Host "  [OK] $LinkPath -> $TargetPath" -ForegroundColor Green
}

function Ensure-Repo {
    if (Test-Path (Join-Path $RepoDir ".git")) {
        Write-Host "  Updating checkout at $RepoDir ..."
        git -C $RepoDir pull --ff-only
    }
    else {
        Write-Host "  Cloning $RepoUrl -> $RepoDir ..."
        $parent = Split-Path -Parent $RepoDir
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        git clone $RepoUrl $RepoDir
    }
}

function Ensure-Pnpm {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        return "pnpm"
    }
    if (Get-Command corepack -ErrorAction SilentlyContinue) {
        Write-Host "  Enabling pnpm via corepack ..."
        corepack enable pnpm | Out-Null
        if (Get-Command pnpm -ErrorAction SilentlyContinue) {
            return "pnpm"
        }
    }
    Write-Host "  Using npx pnpm ..."
    return "npx"
}

function Build-Plugin {
    Push-Location $RepoDir
    try {
        $pnpm = Ensure-Pnpm
        if ($pnpm -eq "npx") {
            npx --yes pnpm@10.6.2 install
            if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
            npx --yes pnpm@10.6.2 run build
        }
        else {
            pnpm install
            if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
            pnpm run build
        }
        if ($LASTEXITCODE -ne 0) { throw "pnpm build failed" }
    }
    finally {
        Pop-Location
    }
}

Write-Host "Understand Anything init (Lum1104/Understand-Anything)" -ForegroundColor Green

Write-Step "Clone / update global checkout"
Ensure-Repo

Write-Step "Link universal plugin root (~/.understand-anything-plugin)"
New-JunctionSafe -LinkPath $PluginLink -TargetPath $PluginDir -Replace:$Force

if (-not $SkipBuild) {
    Write-Step "Build plugin packages (pnpm install + build)"
    try {
        Build-Plugin
    }
    catch {
        Write-Host "  [WARN] Build failed: $_" -ForegroundColor Yellow
        Write-Host "  First /understand run may retry build. You can rerun this script later." -ForegroundColor DarkGray
    }
}
else {
    Write-Host "  [SKIP] Build skipped (-SkipBuild)"
}

if ($ProjectPath -and (Test-Path $ProjectPath)) {
    Write-Step "Wire Cursor plugin into project"
    $root = (Resolve-Path $ProjectPath).Path
    New-JunctionSafe -LinkPath (Join-Path $root ".cursor-plugin") -TargetPath $CursorPluginDir -Replace:$Force
    New-JunctionSafe -LinkPath (Join-Path $root "understand-anything-plugin") -TargetPath $PluginDir -Replace:$Force
}
else {
    Write-Host "  [SKIP] No -ProjectPath; Cursor discovers plugin only in wired projects." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Restart Cursor, then in a wired business project run: /understand --language zh" -ForegroundColor Green
Write-Host "Dashboard: /understand-dashboard | Docs: https://github.com/Lum1104/Understand-Anything" -ForegroundColor DarkGray
