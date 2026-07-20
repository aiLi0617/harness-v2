# Harness Hook 冒烟测试（Windows）
#
# 用途：
#   验证规则机械注入 Hook 的文件完整性、Node 语法，以及两个核心路径的端到端行为：
#   1. beforeSubmitPrompt — 编码 prompt 应返回 additional_context
#   2. preToolUse         — 写 .java 文件应返回 permission: allow 并完成规则注入
#
# 运行：
#   powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/scripts/smoke-hooks.ps1
#
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure([string]$Message) { $script:failures.Add($Message) }

$hooksJson = Join-Path $Root '.cursor\hooks.json'
$requiredScripts = @(
  '.cursor\hooks\handle-before-submit.mjs',
  '.cursor\hooks\handle-pre-tool-use.mjs',
  '.cursor\hooks\handle-session-start.mjs',
  '.cursor\hooks\lib\rules-engine.mjs'
)

if (-not (Test-Path $hooksJson)) {
  Add-Failure 'HOOKS_JSON missing=.cursor/hooks.json'
} else {
  $hooksText = Get-Content $hooksJson -Raw
  foreach ($marker in @('beforeSubmitPrompt', 'preToolUse', 'sessionStart', 'handle-before-submit.mjs', 'handle-pre-tool-use.mjs')) {
    if ($hooksText -notmatch [regex]::Escape($marker)) {
      Add-Failure "HOOKS_JSON missing=$marker"
    }
  }
}

foreach ($rel in $requiredScripts) {
  $path = Join-Path $Root $rel
  if (-not (Test-Path $path)) {
    Add-Failure "HOOK_SCRIPT missing=$rel"
    continue
  }
  & node --check $path
  if ($LASTEXITCODE -ne 0) {
    Add-Failure "HOOK_SCRIPT syntax=$rel"
  }
}

$prompt = '{"prompt":"实现 UserController","open_files":["src/main/java/com/broker/Foo.java"],"conversation_id":"smoke-hook"}'
$beforeOutput = $prompt | & node (Join-Path $Root '.cursor\hooks\handle-before-submit.mjs') 2>&1
if ($LASTEXITCODE -ne 0) {
  Add-Failure 'HOOK_SMOKE beforeSubmitPrompt exit-code'
} elseif ($beforeOutput -notmatch 'additional_context') {
  Add-Failure 'HOOK_SMOKE beforeSubmitPrompt missing additional_context'
}

$enumPrompt = '{"prompt":"update OrderStatusEnum values","open_files":["src/main/java/com/broker/OrderStatusEnum.java"],"conversation_id":"smoke-hook-enums"}'
$enumOutput = $enumPrompt | & node (Join-Path $Root '.cursor\hooks\handle-before-submit.mjs') 2>&1
if ($LASTEXITCODE -ne 0) {
  Add-Failure 'HOOK_SMOKE enums beforeSubmitPrompt exit-code'
} elseif ($enumOutput -notmatch 'enums\.mdc') {
  Add-Failure 'HOOK_SMOKE enums scenario missing enums.mdc injection'
}

$writeGate = '{"tool_name":"Write","tool_input":{"path":"src/main/java/com/broker/Foo.java"},"conversation_id":"smoke-hook-gate"}'
$gateOutput = $writeGate | & node (Join-Path $Root '.cursor\hooks\handle-pre-tool-use.mjs') 2>&1
if ($LASTEXITCODE -ne 0) {
  Add-Failure 'HOOK_SMOKE preToolUse exit-code'
} elseif ($gateOutput -notmatch '"permission"\s*:\s*"allow"') {
  Add-Failure "HOOK_SMOKE preToolUse unexpected output=$gateOutput"
}

if ($failures.Count -gt 0) {
  Write-Host 'Hook smoke failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'Hook smoke passed' -ForegroundColor Green
