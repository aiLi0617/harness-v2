$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Cursor = Join-Path $Root '.cursor'
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError([string]$Message) { $script:errors.Add($Message) }
function Read-Utf8([string]$Path) { [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) }
function Assert-Contains([string]$Text, [string]$Value, [string]$Code) {
    if (-not $Text.Contains($Value)) { Add-ValidationError "$Code missing=$Value" }
}

$agents = @(Get-ChildItem (Join-Path $Cursor 'agents') -Filter '*.md' -File)
$skills = @(Get-ChildItem (Join-Path $Cursor 'skills') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') })
$workflows = @(Get-ChildItem (Join-Path $Cursor 'workflows') -Filter '*.yaml' -File -Recurse)
$rules = @(Get-ChildItem (Join-Path $Cursor 'rules') -Filter '*.mdc' -File -Recurse)
if ($agents.Count -ne 21) { Add-ValidationError "AGENT_COUNT expected=21 actual=$($agents.Count)" }
if ($skills.Count -ne 15) { Add-ValidationError "SKILL_COUNT expected=15 actual=$($skills.Count)" }
if ($workflows.Count -ne 11) { Add-ValidationError "WORKFLOW_COUNT expected=11 actual=$($workflows.Count)" }
if ($rules.Count -ne 72) { Add-ValidationError "RULE_COUNT expected=72 actual=$($rules.Count)" }

foreach ($agent in $agents) {
    $text = Read-Utf8 $agent.FullName
    if ($text -notmatch "(?m)^name:\s*$([regex]::Escape($agent.BaseName))\s*$") {
        Add-ValidationError "AGENT_NAME file=$($agent.Name)"
    }
    if ($text -notmatch '(?m)^description:\s*.+') { Add-ValidationError "AGENT_DESCRIPTION file=$($agent.Name)" }
}
foreach ($skill in $skills) {
    $path = Join-Path $skill.FullName 'SKILL.md'
    $text = Read-Utf8 $path
    if ($text -notmatch "(?m)^name:\s*$([regex]::Escape($skill.Name))\s*$") {
        Add-ValidationError "SKILL_NAME folder=$($skill.Name)"
    }
    if ($text -notmatch '(?m)^description:\s*(>|.+)') { Add-ValidationError "SKILL_DESCRIPTION folder=$($skill.Name)" }
}

foreach ($rule in $rules) {
    $text = (Read-Utf8 $rule.FullName).TrimStart([char]0xFEFF).Replace("`r`n", "`n")
    $meta = [regex]::Match(
        $text,
        '\A---\ndescription: (?<description>[^\n]+)\nglobs:(?<globs>[^\n]*)\nalwaysApply: (?<always>true|false)\n---\n'
    )
    if (-not $meta.Success) {
        Add-ValidationError "RULE_FRONTMATTER file=$($rule.FullName)"
        continue
    }
    $description = $meta.Groups['description'].Value.Trim()
    $globs = $meta.Groups['globs'].Value.Trim()
    $always = $meta.Groups['always'].Value
    if ($description -notmatch '；在.+时') {
        Add-ValidationError "RULE_DESCRIPTION missing trigger semantics file=$($rule.FullName)"
    }
    if ($globs -and ($globs -notmatch '^"[^"\r\n]+"$')) {
        Add-ValidationError "RULE_GLOBS must be quoted scalar file=$($rule.FullName)"
    }
    if ($always -eq 'true' -and $globs) {
        Add-ValidationError "RULE_ACTIVATION always rule must have empty globs file=$($rule.FullName)"
    }
    foreach ($heading in @('# ', '## 适用范围', '## 强制规则', '## 验证清单')) {
        if (-not $text.Contains($heading)) {
            Add-ValidationError "RULE_STRUCTURE missing=$heading file=$($rule.FullName)"
        }
    }
    if ($text -match '(?m)^## (补充规则|补充说明|其他要求|其它|其他)\s*$') {
        Add-ValidationError "RULE_STRUCTURE catch-all heading file=$($rule.FullName)"
    }
    if ($text -match "[\uE000-\uF8FF\uFFFD]|閿欒|缁勫|瑙勭害") {
        Add-ValidationError "RULE_ENCODING mojibake marker file=$($rule.FullName)"
    }
    if ($rule.FullName -match '[\\/]rules[\\/]projects[\\/]broker[\\/]') {
        if ($always -ne 'false' -or -not $globs -or $globs -notmatch 'broker') {
            Add-ValidationError "PROJECT_RULE_SCOPE invalid broker activation file=$($rule.FullName)"
        }
        if (-not $rule.BaseName.StartsWith('broker-')) {
            Add-ValidationError "PROJECT_RULE_NAME missing broker prefix file=$($rule.FullName)"
        }
    }
    if ($rule.FullName -match '[\\/]rules[\\/]projects[\\/]b2cmall[\\/]') {
        if ($always -ne 'false' -or -not $globs -or $globs -notmatch 'b2cmall') {
            Add-ValidationError "PROJECT_RULE_SCOPE invalid b2cmall activation file=$($rule.FullName)"
        }
        if (-not $rule.BaseName.StartsWith('b2cmall-')) {
            Add-ValidationError "PROJECT_RULE_NAME missing b2cmall prefix file=$($rule.FullName)"
        }
    }
}

$authoringSkill = Join-Path $Cursor 'skills\harness-resource-authoring'
foreach ($rel in @('SKILL.md','references\agent-template.md','references\skill-template.md','references\rule-template.mdc')) {
    if (-not (Test-Path (Join-Path $authoringSkill $rel))) {
        Add-ValidationError "AUTHORING_SKILL missing=$rel"
    }
}
foreach ($forbidden in @('README.md','agents','scripts')) {
    if (Test-Path (Join-Path $authoringSkill $forbidden)) {
        Add-ValidationError "AUTHORING_SKILL forbidden=$forbidden"
    }
}

$requiredFields = @('description:', 'agent:', 'skills:', 'entry_artifacts:', 'exit_artifacts:', 'condition:', 'next:')
foreach ($workflow in $workflows) {
    $text = Read-Utf8 $workflow.FullName
    $blocks = [regex]::Matches($text, '(?ms)^  - id:.*?(?=^  - id:|^[A-Za-z_][A-Za-z0-9_-]*:|\z)')
    if (($text.Contains('steps:') -or $text.Contains('phases:')) -and $blocks.Count -eq 0) {
        Add-ValidationError "WORKFLOW_SCHEMA no items in $($workflow.FullName)"
    }
    foreach ($block in $blocks) {
        foreach ($field in $requiredFields) {
            if ($block.Value -notmatch "(?m)^    $([regex]::Escape($field))") {
                Add-ValidationError "WORKFLOW_SCHEMA missing=$field file=$($workflow.Name)"
            }
        }
        foreach ($nested in @('required:', 'on_demand:', 'optional:')) {
            if (-not $block.Value.Contains($nested)) {
                Add-ValidationError "WORKFLOW_SCHEMA missing=$nested file=$($workflow.Name)"
            }
        }
    }
}

$bugfix = Read-Utf8 (Join-Path $Cursor 'workflows\bugfix.yaml')
foreach ($marker in @(
    'default_for_ones_link_only: investigation',
    'fix_requires_explicit_authorization: true',
    'id: intent-routing',
    'id: fix-authorization',
    'id: investigation-complete'
)) { Assert-Contains $bugfix $marker 'BUGFIX_INTENT_ROUTING' }
if ($bugfix.Contains('skills/feature-delivery-workflow')) {
    Add-ValidationError 'BUGFIX_SKILL_BINDING must not use feature-delivery-workflow'
}
if (Test-Path (Join-Path $Root 'docs\migrations')) { Add-ValidationError 'DOCS_MIGRATIONS must remain removed' }

$planner = Read-Utf8 (Join-Path $Cursor 'agents\refactoring-planner.md')
$refactoring = Read-Utf8 (Join-Path $Cursor 'workflows\refactoring.yaml')
Assert-Contains $planner 'context/repository-context.md' 'REPOSITORY_CONTEXT_AGENT'
if ($refactoring -notmatch '(?ms)^  - id: refactoring-plan.*?exit_artifacts:.*context/repository-context\.md') {
    Add-ValidationError 'REPOSITORY_CONTEXT refactoring-plan must produce repository context'
}

$reviewFiles = @(
    (Join-Path $Cursor 'workflows\bugfix.yaml'),
    (Join-Path $Cursor 'workflows\refactoring.yaml'),
    (Join-Path $Cursor 'workflows\feature-delivery\phase-7-code.yaml')
)
$members = @('static-analysis-review','logic-correctness-review','maintainability-review','test-adequacy-review','security-review','data-concurrency-review','diagnosability-review','consistency-review')
foreach ($path in $reviewFiles) {
    $text = Read-Utf8 $path
    foreach ($marker in @(
        'skills/quality-review-routing',
        'next: {on_pass: implementation-quality, on_fail: human-checkpoint}',
        'execution: {mode: parallel, join: all}',
        'routing_artifact: workflow/review-routing.md',
        'join_target: quality-gate'
    )) { Assert-Contains $text $marker "PARALLEL_GROUP $path" }
    foreach ($member in $members) {
        if ($text -notmatch "(?ms)^  - id: $([regex]::Escape($member)).*?implementation-quality\.join") {
            Add-ValidationError "PARALLEL_JOIN member=$member file=$path"
        }
    }
}

$expectedTemplates = @(
    'context/prd-source.md','context/issue-context.md','context/log-evidence.md','context/repository-context.md',
    'analysis/feature-list.md','analysis/root-cause.md','analysis/impact-analysis.md','analysis/log-investigation.md',
    'design/brainstorm-result.md','design/hld.md','design/ddl.md','design/api-contract.md','design/lld.md',
    'plans/implementation-plan.md','plans/refactoring-plan.md','plans/test-plan.md','plans/rollout-plan.md',
    'delivery/change-manifest.md','delivery/publication-links.md','delivery/migration-record.md','delivery/rollout-record.md',
    'workflow/decision-log.md','workflow/harness-debug.md','workflow/workflow-state.md','workflow/intent-routing.md','workflow/review-routing.md','workflow/memory-change.md',
    'quality/verification-report.md','quality/gates/implementation/quality-gate.md'
)
foreach ($rel in $expectedTemplates) {
    if (-not (Test-Path (Join-Path $Root (Join-Path 'docs\templates' $rel)))) {
        Add-ValidationError "TEMPLATE_COVERAGE missing=$rel"
    }
}

$correction = Read-Utf8 (Join-Path $Cursor 'rules\correction-detection.mdc')
$memoryAgent = Read-Utf8 (Join-Path $Cursor 'agents\memory-consolidator.md')
foreach ($marker in @('workflow/memory-change.md','状态为 `PENDING`','禁止直接修改任何 `.mdc`')) {
    Assert-Contains $correction $marker 'MEMORY_CANDIDATE'
}
foreach ($marker in @('状态为 `APPROVED`','目标语义章节','状态更新为 `APPLIED`')) {
    Assert-Contains $memoryAgent $marker 'MEMORY_APPROVAL'
}

$oldAgents = @('ones-issue-fetcher','loki-log-investigator','prd-splitter','bug-analyst','architect-hld','db-ddl','lld-author','impl-planner','spec-reviewer','code-quality-reviewer','code-reviewer')
$textFiles = @(Get-ChildItem $Cursor,(Join-Path $Root 'docs') -File -Recurse | Where-Object {
    $_.Extension -in @('.md','.mdc','.yaml','.yml','.ps1','.sh') -and
    $_.FullName -notmatch '[\\/]archive[\\/]' -and
    $_.Name -ne 'check-harness-resources.ps1'
}) + @(Get-Item (Join-Path $Root 'README.md'))
foreach ($file in $textFiles) {
    $text = Read-Utf8 $file.FullName
    foreach ($old in $oldAgents) {
        if ($text -match "(?<![a-z0-9-])$([regex]::Escape($old))(?![a-z0-9-])") {
            Add-ValidationError "OLD_AGENT name=$old file=$($file.FullName)"
        }
    }
}

$pythonFiles = @(Get-ChildItem $PSScriptRoot -Filter '*.py' -File)
if ($pythonFiles.Count -gt 0) { Add-ValidationError "SCRIPT_TYPE python files remain=$($pythonFiles.Name -join ',')" }

if ($errors.Count -gt 0) {
    Write-Host 'Harness resource validation failed:' -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'Harness resource validation passed' -ForegroundColor Green
