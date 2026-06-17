#!/usr/bin/env pwsh
# 规则交叉引用检查：叶子规则正文禁止引用其他 .mdc 文件，仅路由层白名单可引用。
# 退出码 0 = 通过；1 = 发现违规；2 = 目录缺失。检查口径以 .cursor/rules/cross-ref-guard.mdc 为准。
# 注意：输出文案保持 ASCII，避免 Windows PowerShell 以 GBK 读取本脚本时解析报错。
[CmdletBinding()]
param(
    [string]$RulesDir = ".cursor/rules"
)

$ErrorActionPreference = "Stop"

# 路由层白名单：允许在正文引用其他 .mdc 路径（仅限映射表 / 流程说明）
$whitelist = @(
    "rules-loader.mdc",
    "correction-detection.mdc",
    "cross-ref-guard.mdc",
    "java-edit-self-check.mdc"
)

if (-not (Test-Path -LiteralPath $RulesDir)) {
    Write-Error "Rules directory not found: $RulesDir"
    exit 2
}

$pattern = '[A-Za-z0-9_-]+\.mdc'
$violations = New-Object System.Collections.Generic.List[object]

Get-ChildItem -Path $RulesDir -Recurse -Filter *.mdc -File | ForEach-Object {
    $file = $_
    if ($whitelist -contains $file.Name) { return }

    $lineNo = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNo++
        foreach ($match in [regex]::Matches($line, $pattern)) {
            if ($match.Value -ieq $file.Name) { continue }  # ignore self-reference
            $violations.Add([pscustomobject]@{
                File = $file.FullName
                Line = $lineNo
                Ref  = $match.Value
                Text = $line.Trim()
            })
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host ("[FAIL] cross-ref check failed: found {0} leaf-rule cross-file reference(s):" -f $violations.Count) -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host ("  {0}:{1}  ->  {2}" -f $v.File, $v.Line, $v.Ref) -ForegroundColor Yellow
        Write-Host ("      {0}" -f $v.Text) -ForegroundColor DarkGray
    }
    Write-Host "Fix: remove .mdc references from leaf rules; load side-by-side in rules-loader.mdc, or inline the needed clauses." -ForegroundColor Red
    exit 1
}

Write-Host "[PASS] cross-ref check passed: no cross-file .mdc references in leaf rules." -ForegroundColor Green
exit 0
