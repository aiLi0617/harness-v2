<#
.SYNOPSIS
    将 Harness Cursor 配置链接到目标业务项目，并复制 MCP 工作区模板。

.DESCRIPTION
    目录链接: .cursor/agents, rules, skills, workflows, scripts
    硬链（文件）: .cursor/AGENTS.md, .cursor/CLAUDE.md  （Windows）
    本地目录: docs/artifacts/work, docs/artifacts/archive
    复制（独立）: .cursor/mcp-workspace/mcp.workspace.json, mcp.workspace.secrets.json

.PARAMETER Target
    目标业务项目根目录（必填）

.PARAMETER Force
    覆盖已存在的链接或 MCP 工作区文件

.EXAMPLE
    .\link-cursor-config.ps1 -Target "D:\Work\Project\Java\broker"
    .\link-cursor-config.ps1 -Target "D:\Work\Project\Java\broker" -Force
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$Source = $PSScriptRoot

if (-not (Test-Path $Source)) {
    Write-Error "源目录不存在: $Source"
    exit 1
}
if (-not (Test-Path $Target)) {
    Write-Error "目标目录不存在: $Target"
    exit 1
}

$Target = (Resolve-Path $Target).Path
$Source = (Resolve-Path $Source).Path

if ($Target -eq $Source) {
    Write-Error "目标目录不能是 Harness 源目录本身"
    exit 1
}
if ($Target.StartsWith($Source + [IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "目标目录不能位于 Harness 源目录内部，避免产生循环链接: $Target"
    exit 1
}

$linkDirs = @(
    ".cursor\agents"
    ".cursor\rules"
    ".cursor\skills"
    ".cursor\workflows"
    ".cursor\scripts"
)

$localDirs = @(
    "docs\artifacts\work"
    "docs\artifacts\archive"
)

$linkFiles = @(
    ".cursor\AGENTS.md"
    ".cursor\CLAUDE.md"
)

$successCount = 0
$skipCount = 0
$failCount = 0

function Write-LinkResult {
    param(
        [string]$RelPath,
        [string]$Mode,
        [bool]$Ok,
        [string]$Detail = ""
    )
    if ($Ok) {
        Write-Host "[OK] $RelPath ($Mode)" -ForegroundColor Green
        if ($Detail) {
            Write-Host "     $Detail" -ForegroundColor DarkGray
        }
        $script:successCount++
    } else {
        Write-Host "[SKIP] $RelPath — $Detail" -ForegroundColor Yellow
        $script:skipCount++
    }
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path $Path -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Remove-ExistingTarget {
    param(
        [string]$DstPath,
        [bool]$IsDir
    )
    if (-not (Test-Path $DstPath)) {
        return $true
    }

    $existing = Get-Item $DstPath -Force
    if ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        if ($Force) {
            $existing.Delete()
            Write-Host "  移除旧链接: $DstPath" -ForegroundColor Yellow
            return $true
        }
        return $false
    }

    if ($Force) {
        if ($IsDir) {
            Remove-Item $DstPath -Recurse -Force
        } else {
            Remove-Item $DstPath -Force
        }
        Write-Host "  移除已有项: $DstPath" -ForegroundColor Yellow
        return $true
    }

    return $false
}

Write-Host ""
Write-Host "=== 软链目录 ===" -ForegroundColor Cyan
foreach ($rel in $linkDirs) {
    $srcPath = Join-Path $Source $rel
    $dstPath = Join-Path $Target $rel

    if (-not (Test-Path $srcPath)) {
        Write-LinkResult -RelPath $rel -Mode "junction" -Ok $false -Detail "源不存在"
        continue
    }

    Ensure-ParentDirectory -Path $dstPath
    if (-not (Remove-ExistingTarget -DstPath $dstPath -IsDir $true)) {
        Write-LinkResult -RelPath $rel -Mode "junction" -Ok $false -Detail "已存在（使用 -Force 覆盖）"
        continue
    }

    try {
        cmd /c mklink /J "$dstPath" "$srcPath" | Out-Null
        Write-LinkResult -RelPath $rel -Mode "junction" -Ok $true -Detail "$srcPath -> $dstPath"
    } catch {
        Write-Error "[FAIL] $rel : $_"
        $failCount++
    }
}

Write-Host ""
Write-Host "=== 硬链文件 ===" -ForegroundColor Cyan
foreach ($rel in $linkFiles) {
    $srcPath = Join-Path $Source $rel
    $dstPath = Join-Path $Target $rel

    if (-not (Test-Path $srcPath)) {
        Write-LinkResult -RelPath $rel -Mode "hardlink" -Ok $false -Detail "源不存在"
        continue
    }

    Ensure-ParentDirectory -Path $dstPath
    if (-not (Remove-ExistingTarget -DstPath $dstPath -IsDir $false)) {
        Write-LinkResult -RelPath $rel -Mode "hardlink" -Ok $false -Detail "已存在（使用 -Force 覆盖）"
        continue
    }

    try {
        fsutil hardlink create "$dstPath" "$srcPath" | Out-Null
        Write-LinkResult -RelPath $rel -Mode "hardlink" -Ok $true -Detail "$srcPath -> $dstPath"
    } catch {
        Write-Error "[FAIL] $rel : $_"
        $failCount++
    }
}

Write-Host ""
Write-Host "=== 初始化目标项目本地目录 ===" -ForegroundColor Cyan
foreach ($rel in $localDirs) {
    $dstPath = Join-Path $Target $rel
    if (-not (Test-Path $dstPath)) {
        New-Item -ItemType Directory -Path $dstPath -Force | Out-Null
        Write-LinkResult -RelPath $rel -Mode "local" -Ok $true -Detail "目标项目独立目录，不链接回 Harness"
    } else {
        Write-Host "[OK] $rel (local, 已存在)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== 复制 MCP 工作区 ===" -ForegroundColor Cyan

$mcpWorkspaceDir = Join-Path $Target ".cursor\mcp-workspace"
$mcpWorkspaceFile = Join-Path $mcpWorkspaceDir "mcp.workspace.json"
$mcpSecretsFile = Join-Path $mcpWorkspaceDir "mcp.workspace.secrets.json"
$workspaceTemplate = Join-Path $Source ".cursor\skills\mcp-switch\mcp.workspace.link-template.json"
$secretsTemplate = Join-Path $Source ".cursor\skills\mcp-switch\mcp.workspace.secrets.example.json"

if (-not (Test-Path $mcpWorkspaceDir)) {
    New-Item -ItemType Directory -Path $mcpWorkspaceDir -Force | Out-Null
}

if (Test-Path $workspaceTemplate) {
    if ((Test-Path $mcpWorkspaceFile) -and -not $Force) {
        Write-LinkResult -RelPath ".cursor\mcp-workspace\mcp.workspace.json" -Mode "copy" -Ok $false -Detail "已存在（使用 -Force 覆盖）"
    } else {
        $content = Get-Content -Path $workspaceTemplate -Raw -Encoding UTF8
        $normalizedTarget = $Target -replace '\\', '/'
        $content = $content.Replace('__TARGET_PROJECT_PATH__', $normalizedTarget)
        Set-Content -Path $mcpWorkspaceFile -Value $content -Encoding UTF8 -NoNewline
        Write-LinkResult -RelPath ".cursor\mcp-workspace\mcp.workspace.json" -Mode "copy" -Ok $true
    }
} else {
    Write-LinkResult -RelPath ".cursor\mcp-workspace\mcp.workspace.json" -Mode "copy" -Ok $false -Detail "模板不存在: mcp.workspace.link-template.json"
}

if (Test-Path $secretsTemplate) {
    if ((Test-Path $mcpSecretsFile) -and -not $Force) {
        Write-LinkResult -RelPath ".cursor\mcp-workspace\mcp.workspace.secrets.json" -Mode "copy" -Ok $false -Detail "已存在（使用 -Force 覆盖）"
    } else {
        Copy-Item -Path $secretsTemplate -Destination $mcpSecretsFile -Force
        Write-LinkResult -RelPath ".cursor\mcp-workspace\mcp.workspace.secrets.json" -Mode "copy" -Ok $true
    }
} else {
    Write-LinkResult -RelPath ".cursor\mcp-workspace\mcp.workspace.secrets.json" -Mode "copy" -Ok $false -Detail "模板不存在: mcp.workspace.secrets.example.json"
}

Write-Host ""
Write-Host "完成: 成功 $successCount, 跳过 $skipCount, 失败 $failCount" -ForegroundColor Cyan

Write-Host ""
Write-Host "[提示] MCP 初始化" -ForegroundColor Magenta
Write-Host "  1. 编辑 .cursor/mcp-workspace/mcp.workspace.json" -ForegroundColor DarkGray
Write-Host "  2. 编辑 .cursor/mcp-workspace/mcp.workspace.secrets.json" -ForegroundColor DarkGray
Write-Host "  3. powershell -File .cursor/skills/mcp-install/scripts/init-mcp.ps1 -Profile dev" -ForegroundColor DarkGray
Write-Host "  日常切换: powershell -File .cursor/skills/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev" -ForegroundColor DarkGray

Write-Host ""
Write-Host "[提示] 可选：初始化 CodeGraph 索引" -ForegroundColor Magenta
Write-Host "  powershell -File `"$Source\.cursor\scripts\init-codegraph.ps1`" -ProjectPath `"$Target`"" -ForegroundColor DarkGray

if ($failCount -gt 0) {
    exit 1
}
