# Check leaf .mdc rules for cross-file references to other .mdc files
# Usage (Windows): powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/check-rule-cross-refs.ps1
# Usage (macOS/Linux): .cursor/scripts/check-rule-cross-refs.sh
# Exit code: 0=pass, 1=violations found

param(
    [string]$RulesRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RulesRoot)) {
    $RulesRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\rules")).Path
} else {
    $RulesRoot = (Resolve-Path $RulesRoot).Path
}

$Allowlist = @(
    "orchestration/coding-standards-loader.mdc",
    "feedback/correction-detection.mdc",
    "feedback/java-edit-self-check.mdc",
    "feedback/rule-cross-ref-guard.mdc"
)

function Get-RelativeRulePath {
    param([System.IO.FileInfo]$File, [string]$Root)
    $relative = $File.FullName.Substring($Root.Length).TrimStart('\', '/')
    return ($relative -replace '\\', '/')
}

function Test-CrossRefLine {
    param(
        [string]$Line,
        [string]$Stem
    )

    if ($Line -match '[`'']([\w-]+)\.mdc[`'']') {
        if ($Matches[1] -ne $Stem) {
            return @{ Hit = $true; Pattern = "backtick .mdc" }
        }
    }

    if ($Line -match 'rules/(?:memory|feedback|orchestration|execution)/[\w-]+\.mdc') {
        return @{ Hit = $true; Pattern = "rules/ path" }
    }

    $verbPatterns = @(
        @{ Pattern = '(?:\u89c1|\u8be6\u89c1|\u914d\u5408|\u53c2\u89c1|\u53c2\u8003)\s*[`'']?[\w-]+\.mdc'; Name = "see xxx.mdc" },
        @{ Pattern = '\u4e0e\s*[`'']?[\w-]+\.mdc'; Name = "with xxx.mdc" }
    )

    foreach ($vp in $verbPatterns) {
        if ($Line -match $vp.Pattern) {
            return @{ Hit = $true; Pattern = $vp.Name }
        }
    }

    return @{ Hit = $false; Pattern = "" }
}

$violations = @()
$mdcFiles = Get-ChildItem -Path $RulesRoot -Filter "*.mdc" -Recurse -File

foreach ($file in $mdcFiles) {
    $relativePath = Get-RelativeRulePath -File $file -Root $RulesRoot
    if ($Allowlist -contains $relativePath) {
        continue
    }

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $lines = Get-Content -Path $file.FullName -Encoding UTF8
    $inCodeFence = $false

    for ($lineNum = 0; $lineNum -lt $lines.Count; $lineNum++) {
        $line = $lines[$lineNum]
        $displayLine = $lineNum + 1

        if ($line -match '^\s*```') {
            $inCodeFence = -not $inCodeFence
            continue
        }
        if ($inCodeFence) {
            continue
        }

        $result = Test-CrossRefLine -Line $line -Stem $stem
        if ($result.Hit) {
            $violations += [PSCustomObject]@{
                File    = $relativePath
                Line    = $displayLine
                Pattern = $result.Pattern
                Content = $line.Trim()
            }
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "OK: no cross-file .mdc references in leaf rules ($($mdcFiles.Count) files scanned)."
    exit 0
}

Write-Host "FAIL: found $($violations.Count) cross-file .mdc reference(s):" -ForegroundColor Red
foreach ($v in $violations) {
    Write-Host "  $($v.File):$($v.Line) [$($v.Pattern)]"
    Write-Host "    $($v.Content)" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "Fix: inline the constraint or add a loader scene entry. See feedback/rule-cross-ref-guard.mdc."
exit 1
