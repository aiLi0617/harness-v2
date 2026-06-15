<#
.SYNOPSIS
    将本项目的 Cursor 配置（agents、rules、skills、workflows、AGENTS.md、CLAUDE.md、mcp/mcp-template.json）
    软连接/复制到指定目标项目目录。

.PARAMETER Target
    目标项目的根目录路径（必填）

.PARAMETER Force
    如果目标位置已存在同名文件/目录，先删除再创建软连接

.EXAMPLE
    .\link-cursor-config.ps1 -Target "D:\Work\Project\Java\456"
    .\link-cursor-config.ps1 -Target "D:\Work\Project\Java\456" -Force
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

$items = @(
    @{ Src = ".cursor\agents";    IsDir = $true  }
    @{ Src = ".cursor\rules";     IsDir = $true  }
    @{ Src = ".cursor\skills";    IsDir = $true  }
    @{ Src = ".cursor\workflows"; IsDir = $true  }
    @{ Src = ".cursor\scripts";  IsDir = $true  }
    @{ Src = ".cursor\plugins";  IsDir = $true  }
    @{ Src = ".cursor\AGENTS.md"; IsDir = $false }
    @{ Src = ".cursor\CLAUDE.md"; IsDir = $false }
    @{ Src = "docs";              IsDir = $true  }
)

# MCP 模板单独处理：复制而非链接（每个项目需独立配置密钥）
$mcpTemplateSrc = Join-Path $Source ".cursor\mcp\mcp-template.json"
$mcpTemplateDst = Join-Path $Target ".cursor\mcp\mcp-template.json"
$mcpJsonDst     = Join-Path $Target ".cursor\mcp.json"

if (Test-Path $mcpTemplateSrc) {
    $mcpParent = Split-Path $mcpTemplateDst -Parent
    if (-not (Test-Path $mcpParent)) {
        New-Item -ItemType Directory -Path $mcpParent -Force | Out-Null
    }

    if ((Test-Path $mcpTemplateDst) -and -not $Force) {
        Write-Host "[SKIP] MCP 模板已存在，跳过（使用 -Force 覆盖）: .cursor\mcp\mcp-template.json" -ForegroundColor Yellow
        $skipCount++
    } else {
        Copy-Item -Path $mcpTemplateSrc -Destination $mcpTemplateDst -Force
        Write-Host "[OK] .cursor\mcp\mcp-template.json（复制）" -ForegroundColor Green
        $successCount++
    }

    if (-not (Test-Path $mcpJsonDst)) {
        Write-Host ""
        Write-Host "[提示] 请复制 .cursor\mcp\mcp-template.json 为 .cursor\mcp.json 并填入实际密钥" -ForegroundColor Magenta
    }
} else {
    Write-Host "[SKIP] 源不存在，跳过: .cursor\mcp\mcp-template.json" -ForegroundColor Yellow
    $skipCount++
}

Write-Host ""
Write-Host "[提示] 可选：在业务项目根目录初始化 CodeGraph 索引" -ForegroundColor Magenta
Write-Host "  powershell -File `"$Source\.cursor\scripts\init-codegraph.ps1`" -ProjectPath `"$Target`"" -ForegroundColor DarkGray

$successCount = 0
$skipCount = 0
$failCount = 0

foreach ($item in $items) {
    $srcPath = Join-Path $Source $item.Src
    $dstPath = Join-Path $Target $item.Src

    if (-not (Test-Path $srcPath)) {
        Write-Host "[SKIP] 源不存在，跳过: $($item.Src)" -ForegroundColor Yellow
        $skipCount++
        continue
    }

    $dstParent = Split-Path $dstPath -Parent
    if (-not (Test-Path $dstParent)) {
        New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
        Write-Host "  创建父目录: $dstParent" -ForegroundColor DarkGray
    }

    if (Test-Path $dstPath) {
        $existing = Get-Item $dstPath -Force
        if ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            if ($Force) {
                $existing.Delete()
                Write-Host "  移除旧软连接: $dstPath" -ForegroundColor Yellow
            } else {
                Write-Host "[SKIP] 已存在软连接，跳过（使用 -Force 覆盖）: $($item.Src)" -ForegroundColor Yellow
                $skipCount++
                continue
            }
        } elseif ($Force) {
            if ($item.IsDir) {
                Remove-Item $dstPath -Recurse -Force
            } else {
                Remove-Item $dstPath -Force
            }
            Write-Host "  移除已有项: $dstPath" -ForegroundColor Yellow
        } else {
            Write-Host "[SKIP] 目标已存在且非软连接，跳过（使用 -Force 覆盖）: $($item.Src)" -ForegroundColor Yellow
            $skipCount++
            continue
        }
    }

    try {
        if ($item.IsDir) {
            cmd /c mklink /J "$dstPath" "$srcPath" | Out-Null
        } else {
            fsutil hardlink create "$dstPath" "$srcPath" | Out-Null
        }
        Write-Host "[OK] $($item.Src)" -ForegroundColor Green
        Write-Host "     $srcPath -> $dstPath" -ForegroundColor DarkGray
        $successCount++
    } catch {
        Write-Error "[FAIL] $($item.Src): $_"
        $failCount++
    }
}

Write-Host ""
Write-Host "完成: 成功 $successCount, 跳过 $skipCount, 失败 $failCount" -ForegroundColor Cyan

if ($failCount -gt 0) {
    exit 1
}
