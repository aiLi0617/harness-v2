$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$WorkflowRoot = Join-Path $Root '.cursor\workflows'
$failures = [System.Collections.Generic.List[string]]::new()

function Read-Utf8([string]$Path) { [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) }
function Assert-Contains([string]$Path, [string]$Value, [string]$Scenario) {
    if (-not (Read-Utf8 $Path).Contains($Value)) { $script:failures.Add("$Scenario missing=$Value file=$Path") }
}
function Assert-ParallelGroup([string]$Path, [string]$Scenario) {
    $text = Read-Utf8 $Path
    $members = @('static-analysis-review','logic-correctness-review','maintainability-review','test-adequacy-review','security-review','data-concurrency-review','diagnosability-review','consistency-review')
    foreach ($marker in @(
        'next: {on_pass: implementation-quality, on_fail: human-checkpoint}',
        'execution: {mode: parallel, join: all}',
        'routing_artifact: workflow/review-routing.md',
        'join_target: quality-gate'
    )) {
        if (-not $text.Contains($marker)) { $script:failures.Add("$Scenario missing=$marker") }
    }
    foreach ($member in $members) {
        if ($text -notmatch "(?ms)^  - id: $([regex]::Escape($member)).*?implementation-quality\.join") {
            $script:failures.Add("$Scenario member=$member does not reach join")
        }
    }
}

$bugfix = Join-Path $WorkflowRoot 'bugfix.yaml'
foreach ($marker in @(
    'default_for_ones_link_only: investigation',
    'next: {on_pass: implementation-plan, on_skip: investigation-complete, on_fail: human-checkpoint}',
    'next: {on_pass: end, on_fail: human-checkpoint}',
    'exit_artifacts: [analysis/root-cause.md]'
)) { Assert-Contains $bugfix $marker 'bugfix/investigation' }
$investigationBlock = [regex]::Match(
    (Read-Utf8 $bugfix),
    '(?ms)^  - id: investigation-complete.*?(?=^  - id:|^[A-Za-z_][A-Za-z0-9_-]*:|\z)'
).Value
if ($investigationBlock.Contains('delivery/change-manifest.md')) {
    $failures.Add('bugfix/investigation unexpectedly produces change-manifest')
}
foreach ($marker in @(
    'exit_artifacts: [delivery/change-manifest.md]',
    'exit_artifacts: [workflow/review-routing.md]',
    'exit_artifacts: [quality/gates/implementation/quality-gate.md]',
    'exit_artifacts: [quality/verification-report.md]',
    'exit_artifacts: [archive/{date}-{task-id}/]'
)) { Assert-Contains $bugfix $marker 'bugfix/fix' }
Assert-ParallelGroup $bugfix 'bugfix/fix'

$refactoring = Join-Path $WorkflowRoot 'refactoring.yaml'
foreach ($marker in @(
    'exit_artifacts: [context/repository-context.md, analysis/impact-analysis.md, plans/refactoring-plan.md]',
    'exit_artifacts: [delivery/change-manifest.md]',
    'exit_artifacts: [workflow/review-routing.md]',
    'exit_artifacts: [quality/gates/implementation/quality-gate.md]',
    'exit_artifacts: [quality/verification-report.md]',
    'exit_artifacts: [archive/{date}-{task-id}/]'
)) { Assert-Contains $refactoring $marker 'refactoring' }
Assert-ParallelGroup $refactoring 'refactoring'

$feature = Join-Path $WorkflowRoot 'feature-delivery.yaml'
$featureText = Read-Utf8 $feature
$phaseRefs = [regex]::Matches($featureText, '(?m)^    file:\s*workflows/feature-delivery/[^\r\n]+\.yaml\s*$')
if ($phaseRefs.Count -ne 8) { $failures.Add("feature-delivery expected=8 phases actual=$($phaseRefs.Count)") }
$featureMarkers = @(
    @{ File='phase-1-prd-split.yaml'; Value='exit_artifacts: [analysis/feature-list.md]' },
    @{ File='phase-2-brainstorm.yaml'; Value='exit_artifacts: [design/brainstorm-result.md]' },
    @{ File='phase-3-hld.yaml'; Value='quality/gates/hld-design/quality-gate.md' },
    @{ File='phase-4-db-api.yaml'; Value='execution: {mode: parallel, join: all}' },
    @{ File='phase-4-db-api.yaml'; Value='exit_artifacts: [design/ddl.md]' },
    @{ File='phase-4-db-api.yaml'; Value='exit_artifacts: [design/api-contract.md]' },
    @{ File='phase-5-lld.yaml'; Value='quality/gates/lld-design/quality-gate.md' },
    @{ File='phase-6-plan.yaml'; Value='exit_artifacts: [plans/implementation-plan.md]' },
    @{ File='phase-8-verify-archive.yaml'; Value='exit_artifacts: [quality/verification-report.md]' },
    @{ File='phase-8-verify-archive.yaml'; Value='exit_artifacts: [archive/{date}-{task-id}/]' }
)
foreach ($item in $featureMarkers) {
    Assert-Contains (Join-Path $WorkflowRoot "feature-delivery\$($item.File)") $item.Value 'feature-delivery'
}
Assert-ParallelGroup (Join-Path $WorkflowRoot 'feature-delivery\phase-7-code.yaml') 'feature-delivery'

if ($failures.Count -gt 0) {
    Write-Host 'Workflow smoke failed:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'PASS bugfix/investigation: ONES-only stops after root cause'
Write-Host 'PASS bugfix/fix: implementation -> fan-out/join -> gate -> verification -> archive'
Write-Host 'PASS refactoring: repository context -> plan -> implementation -> quality -> archive'
Write-Host 'PASS feature-delivery: 8 phases, DB/API parallel, design and implementation gates'
Write-Host 'Workflow smoke passed: 3 workflows / 4 scenarios' -ForegroundColor Green
