#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CURSOR="$ROOT/.cursor"
errors=0

fail() { echo "- $*" >&2; errors=$((errors + 1)); }
contains() { grep -Fq -- "$2" "$1" || fail "$3 missing=$2"; }

agent_count=$(find "$CURSOR/agents" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
skill_count=$(find "$CURSOR/skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | wc -l | tr -d ' ')
workflow_count=$(find "$CURSOR/workflows" -type f -name '*.yaml' | wc -l | tr -d ' ')
rule_count=$(find "$CURSOR/rules" -type f -name '*.mdc' | wc -l | tr -d ' ')
[[ "$agent_count" == 21 ]] || fail "AGENT_COUNT expected=21 actual=$agent_count"
[[ "$skill_count" == 15 ]] || fail "SKILL_COUNT expected=15 actual=$skill_count"
[[ "$workflow_count" == 11 ]] || fail "WORKFLOW_COUNT expected=11 actual=$workflow_count"
[[ "$rule_count" == 72 ]] || fail "RULE_COUNT expected=72 actual=$rule_count"

while IFS= read -r file; do
    name="$(basename "$file" .md)"
    grep -Eq "^name:[[:space:]]*$name[[:space:]]*$" "$file" || fail "AGENT_NAME file=$file"
    grep -Eq '^description:[[:space:]]*.+' "$file" || fail "AGENT_DESCRIPTION file=$file"
done < <(find "$CURSOR/agents" -maxdepth 1 -type f -name '*.md' | sort)

while IFS= read -r file; do
    name="$(basename "$(dirname "$file")")"
    grep -Eq "^name:[[:space:]]*$name[[:space:]]*$" "$file" || fail "SKILL_NAME file=$file"
    grep -Eq '^description:[[:space:]]*(>|.+)' "$file" || fail "SKILL_DESCRIPTION file=$file"
done < <(find "$CURSOR/skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | sort)

while IFS= read -r file; do
    line1="$(sed -n '1p' "$file")"
    line2="$(sed -n '2p' "$file")"
    line3="$(sed -n '3p' "$file")"
    line4="$(sed -n '4p' "$file")"
    line5="$(sed -n '5p' "$file")"
    if [[ "$line1" != '---' || "$line2" != description:* || "$line4" != 'alwaysApply: true' && "$line4" != 'alwaysApply: false' || "$line5" != '---' ]]; then
        fail "RULE_FRONTMATTER field order file=$file"
    fi
    [[ "$line2" =~ ^description:\ .+；在.+时 ]] || fail "RULE_DESCRIPTION file=$file"
    [[ "$line3" == 'globs:' || "$line3" =~ ^globs:\ \"[^\"]+\"$ ]] || fail "RULE_GLOBS quoted-scalar file=$file"
    if [[ "$line4" == 'alwaysApply: true' && "$line3" != 'globs:' ]]; then
        fail "RULE_ACTIVATION always rule must have empty globs file=$file"
    fi
    for heading in '# ' '## 适用范围' '## 强制规则' '## 验证清单'; do
        grep -Fq "$heading" "$file" || fail "RULE_STRUCTURE missing=$heading file=$file"
    done
    if grep -Eq '^## (补充规则|补充说明|其他要求|其它|其他)[[:space:]]*$' "$file"; then
        fail "RULE_STRUCTURE catch-all heading file=$file"
    fi
    if grep -Eq '閿欒|缁勫|瑙勭害|�' "$file"; then
        fail "RULE_ENCODING mojibake marker file=$file"
    fi
    if [[ "$file" == *'/rules/projects/broker/'* ]]; then
        grep -Eq '^alwaysApply: false$' "$file" || fail "PROJECT_RULE alwaysApply file=$file"
        grep -Eq '^globs: ".*broker.*"$' "$file" || fail "PROJECT_RULE globs file=$file"
        [[ "$(basename "$file")" == broker-* ]] || fail "PROJECT_RULE name file=$file"
    fi
    if [[ "$file" == *'/rules/projects/b2cmall/'* ]]; then
        grep -Eq '^alwaysApply: false$' "$file" || fail "PROJECT_RULE alwaysApply file=$file"
        grep -Eq '^globs: ".*b2cmall.*"$' "$file" || fail "PROJECT_RULE globs file=$file"
        [[ "$(basename "$file")" == b2cmall-* ]] || fail "PROJECT_RULE name file=$file"
    fi
done < <(find "$CURSOR/rules" -type f -name '*.mdc' | sort)

authoring="$CURSOR/skills/harness-resource-authoring"
for rel in SKILL.md references/agent-template.md references/skill-template.md references/rule-template.mdc; do
    [[ -f "$authoring/$rel" ]] || fail "AUTHORING_SKILL missing=$rel"
done
for forbidden in README.md agents scripts; do
    [[ ! -e "$authoring/$forbidden" ]] || fail "AUTHORING_SKILL forbidden=$forbidden"
done

bugfix="$CURSOR/workflows/bugfix.yaml"
for marker in \
    'default_for_ones_link_only: investigation' \
    'fix_requires_explicit_authorization: true' \
    'id: intent-routing' 'id: fix-authorization' 'id: investigation-complete'; do
    contains "$bugfix" "$marker" BUGFIX_INTENT_ROUTING
done
if grep -Fq 'skills/feature-delivery-workflow' "$bugfix"; then
    fail 'BUGFIX_SKILL_BINDING must not use feature-delivery-workflow'
fi
[[ ! -d "$ROOT/docs/migrations" ]] || fail 'DOCS_MIGRATIONS must remain removed'

contains "$CURSOR/agents/refactoring-planner.md" 'context/repository-context.md' REPOSITORY_CONTEXT_AGENT
contains "$CURSOR/workflows/refactoring.yaml" 'exit_artifacts: [context/repository-context.md, analysis/impact-analysis.md, plans/refactoring-plan.md]' REPOSITORY_CONTEXT_WORKFLOW

members=(static-analysis-review logic-correctness-review maintainability-review test-adequacy-review security-review data-concurrency-review diagnosability-review consistency-review)
review_files=(
    "$CURSOR/workflows/bugfix.yaml"
    "$CURSOR/workflows/refactoring.yaml"
    "$CURSOR/workflows/feature-delivery/phase-7-code.yaml"
)
for file in "${review_files[@]}"; do
    contains "$file" 'skills/quality-review-routing' REVIEW_ROUTING
    contains "$file" 'next: {on_pass: implementation-quality, on_fail: human-checkpoint}' PARALLEL_FANOUT
    contains "$file" 'execution: {mode: parallel, join: all}' PARALLEL_GROUP
    contains "$file" 'routing_artifact: workflow/review-routing.md' PARALLEL_GROUP
    contains "$file" 'join_target: quality-gate' PARALLEL_GROUP
    for member in "${members[@]}"; do
        awk -v id="$member" '
            $0 ~ "^  - id: " id "$" {inside=1; next}
            inside && /^  - id:/ {exit}
            inside && /implementation-quality\.join/ {found=1}
            END {exit !found}
        ' "$file" || fail "PARALLEL_JOIN member=$member file=$file"
    done
done

templates=(
    context/prd-source.md context/issue-context.md context/log-evidence.md context/repository-context.md
    analysis/feature-list.md analysis/root-cause.md analysis/impact-analysis.md analysis/log-investigation.md
    design/brainstorm-result.md design/hld.md design/ddl.md design/api-contract.md design/lld.md
    plans/implementation-plan.md plans/refactoring-plan.md plans/test-plan.md plans/rollout-plan.md
    delivery/change-manifest.md delivery/publication-links.md delivery/migration-record.md delivery/rollout-record.md
    workflow/decision-log.md workflow/harness-debug.md workflow/workflow-state.md workflow/intent-routing.md workflow/review-routing.md workflow/memory-change.md
    quality/verification-report.md quality/gates/implementation/quality-gate.md
)
for rel in "${templates[@]}"; do
    [[ -f "$ROOT/docs/templates/$rel" ]] || fail "TEMPLATE_COVERAGE missing=$rel"
done

contains "$CURSOR/rules/correction-detection.mdc" 'workflow/memory-change.md' MEMORY_CANDIDATE
contains "$CURSOR/rules/correction-detection.mdc" '状态为 `PENDING`' MEMORY_CANDIDATE
contains "$CURSOR/rules/correction-detection.mdc" '禁止直接修改任何 `.mdc`' MEMORY_CANDIDATE
contains "$CURSOR/agents/memory-consolidator.md" '状态为 `APPROVED`' MEMORY_APPROVAL
contains "$CURSOR/agents/memory-consolidator.md" '目标语义章节' MEMORY_APPROVAL
contains "$CURSOR/agents/memory-consolidator.md" '状态更新为 `APPLIED`' MEMORY_APPROVAL

if find "$CURSOR/scripts" -maxdepth 1 -type f -name '*.py' | grep -q .; then
    fail 'SCRIPT_TYPE Python files remain in .cursor/scripts'
fi

hooks_json="$CURSOR/hooks.json"
hook_scripts=(
  hooks/handle-before-submit.mjs
  hooks/handle-pre-tool-use.mjs
  hooks/handle-session-start.mjs
  hooks/lib/rules-engine.mjs
)
[[ -f "$hooks_json" ]] || fail 'HOOKS_JSON missing=.cursor/hooks.json'
hooks_text="$(cat "$hooks_json")"
for marker in beforeSubmitPrompt preToolUse sessionStart; do
  [[ "$hooks_text" == *"$marker"* ]] || fail "HOOKS_JSON missing=$marker"
done
for rel in "${hook_scripts[@]}"; do
  [[ -f "$CURSOR/$rel" ]] || fail "HOOK_SCRIPT missing=$rel"
done

routing_sync="$CURSOR/scripts/check-rule-routing-sync.mjs"
[[ -f "$routing_sync" ]] || fail 'RULE_ROUTING_SYNC missing=check-rule-routing-sync.mjs'
node "$routing_sync" || fail 'RULE_ROUTING_SYNC failed (rules-loader vs rules-engine drift)'

if (( errors > 0 )); then
    echo "Harness resource validation failed: $errors error(s)" >&2
    exit 1
fi
echo 'Harness resource validation passed'
