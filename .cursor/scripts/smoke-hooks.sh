#!/usr/bin/env bash
# Harness Hook 冒烟测试（macOS / Linux）
#
# 用途：
#   验证规则机械注入 Hook 的文件完整性、Node 语法，以及两个核心路径的端到端行为：
#   1. beforeSubmitPrompt — 编码 prompt 应返回 additional_context
#   2. preToolUse         — 写 .java 文件应返回 permission: allow 并完成规则注入
#
# 运行：
#   bash .cursor/scripts/smoke-hooks.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=()

add_failure() { failures+=("$1"); }

HOOKS_JSON="$ROOT/.cursor/hooks.json"
required_scripts=(
  ".cursor/hooks/handle-before-submit.mjs"
  ".cursor/hooks/handle-pre-tool-use.mjs"
  ".cursor/hooks/handle-session-start.mjs"
  ".cursor/hooks/lib/rules-engine.mjs"
)

if [[ ! -f "$HOOKS_JSON" ]]; then
  add_failure "HOOKS_JSON missing=.cursor/hooks.json"
else
  hooks_text="$(cat "$HOOKS_JSON")"
  for marker in beforeSubmitPrompt preToolUse sessionStart handle-before-submit.mjs handle-pre-tool-use.mjs; do
    if [[ "$hooks_text" != *"$marker"* ]]; then
      add_failure "HOOKS_JSON missing=$marker"
    fi
  done
fi

for rel in "${required_scripts[@]}"; do
  path="$ROOT/$rel"
  if [[ ! -f "$path" ]]; then
    add_failure "HOOK_SCRIPT missing=$rel"
    continue
  fi
  node --check "$path"
done

before_output="$(printf '%s' '{"prompt":"实现 UserController","open_files":["src/main/java/com/broker/Foo.java"],"conversation_id":"smoke-hook"}' | node "$ROOT/.cursor/hooks/handle-before-submit.mjs")"
if [[ "$before_output" != *"additional_context"* ]]; then
  add_failure "HOOK_SMOKE beforeSubmitPrompt missing additional_context"
fi

enum_output="$(printf '%s' '{"prompt":"update OrderStatusEnum values","open_files":["src/main/java/com/broker/OrderStatusEnum.java"],"conversation_id":"smoke-hook-enums"}' | node "$ROOT/.cursor/hooks/handle-before-submit.mjs")"
if [[ "$enum_output" != *"enums.mdc"* ]]; then
  add_failure "HOOK_SMOKE enums scenario missing enums.mdc injection"
fi

gate_output="$(printf '%s' '{"tool_name":"Write","tool_input":{"path":"src/main/java/com/broker/Foo.java"},"conversation_id":"smoke-hook-gate"}' | node "$ROOT/.cursor/hooks/handle-pre-tool-use.mjs")"
if [[ "$gate_output" != *'"permission":"allow"'* && "$gate_output" != *'"permission": "allow"'* ]]; then
  add_failure "HOOK_SMOKE preToolUse unexpected output=$gate_output"
fi

if ((${#failures[@]} > 0)); then
  echo "Hook smoke failed:"
  printf -- '- %s\n' "${failures[@]}"
  exit 1
fi

echo "Hook smoke passed"
