#Requires -Version 5.1
<#
.SYNOPSIS
  触发 Cursor Reload Window（无需手动 Ctrl+Shift+P）。

.DESCRIPTION
  通过 Cursor CLI 的 --open-url 向已运行的实例发送 command URI。
  失败时回退到手动提示。

.EXAMPLE
  .\reload-cursor-window.ps1
#>
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Resolve-CursorCli {
    $cmd = Get-Command cursor -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\cursor\resources\app\bin\cursor.cmd"),
        "D:\cursor\resources\app\bin\cursor.cmd"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }
    return $null
}

function Show-ManualReloadHint {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  请手动 Reload Window 使配置生效："
    Write-Host "  Ctrl+Shift+P -> 输入 Reload Window -> 回车"
    Write-Host "========================================"
}

$cli = Resolve-CursorCli
if (-not $cli) {
    if (-not $Quiet) {
        Write-Host "未找到 cursor CLI，无法自动 Reload Window。"
    }
    Show-ManualReloadHint
    exit 1
}

$commandUri = "command:workbench.action.reloadWindow"
& $cli --open-url $commandUri
if ($LASTEXITCODE -ne 0) {
    if (-not $Quiet) {
        Write-Host "自动 Reload 失败（exit $LASTEXITCODE），请手动操作。"
    }
    Show-ManualReloadHint
    exit $LASTEXITCODE
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  已触发 Reload Window，窗口即将刷新..."
    Write-Host "========================================"
}
exit 0
