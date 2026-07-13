#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WF="$ROOT/.cursor/workflows"
failures=0

fail() { echo "- $*" >&2; failures=$((failures + 1)); }
contains() { grep -Fq -- "$2" "$1" || fail "$3 missing=$2 file=$1"; }
parallel_group() {
    local file="$1" scenario="$2" member
    contains "$file" 'next: {on_pass: implementation-quality, on_fail: human-checkpoint}' "$scenario"
    contains "$file" 'execution: {mode: parallel, join: all}' "$scenario"
    contains "$file" 'routing_artifact: workflow/review-routing.md' "$scenario"
    contains "$file" 'join_target: quality-gate' "$scenario"
    for member in static-analysis-review logic-correctness-review maintainability-review test-adequacy-review security-review data-concurrency-review diagnosability-review consistency-review; do
        awk -v id="$member" '
            $0 ~ "^  - id: " id "$" {inside=1; next}
            inside && /^  - id:/ {exit}
            inside && /implementation-quality\.join/ {found=1}
            END {exit !found}
        ' "$file" || fail "$scenario member=$member does not reach join"
    done
}

bugfix="$WF/bugfix.yaml"
for marker in \
    'default_for_ones_link_only: investigation' \
    'next: {on_pass: implementation-plan, on_skip: investigation-complete, on_fail: human-checkpoint}' \
    'exit_artifacts: [analysis/root-cause.md]'; do
    contains "$bugfix" "$marker" bugfix/investigation
done
for marker in \
    'exit_artifacts: [delivery/change-manifest.md]' \
    'exit_artifacts: [workflow/review-routing.md]' \
    'exit_artifacts: [quality/gates/implementation/quality-gate.md]' \
    'exit_artifacts: [quality/verification-report.md]' \
    'exit_artifacts: [archive/{date}-{task-id}/]'; do
    contains "$bugfix" "$marker" bugfix/fix
done
parallel_group "$bugfix" bugfix/fix

refactoring="$WF/refactoring.yaml"
for marker in \
    'exit_artifacts: [context/repository-context.md, analysis/impact-analysis.md, plans/refactoring-plan.md]' \
    'exit_artifacts: [delivery/change-manifest.md]' \
    'exit_artifacts: [workflow/review-routing.md]' \
    'exit_artifacts: [quality/gates/implementation/quality-gate.md]' \
    'exit_artifacts: [quality/verification-report.md]' \
    'exit_artifacts: [archive/{date}-{task-id}/]'; do
    contains "$refactoring" "$marker" refactoring
done
parallel_group "$refactoring" refactoring

phase_count=$(grep -Ec '^    file: workflows/feature-delivery/.+\.yaml$' "$WF/feature-delivery.yaml" || true)
[[ "$phase_count" == 8 ]] || fail "feature-delivery expected=8 phases actual=$phase_count"
contains "$WF/feature-delivery/phase-1-prd-split.yaml" 'exit_artifacts: [analysis/feature-list.md]' feature-delivery
contains "$WF/feature-delivery/phase-2-brainstorm.yaml" 'exit_artifacts: [design/brainstorm-result.md]' feature-delivery
contains "$WF/feature-delivery/phase-3-hld.yaml" 'quality/gates/hld-design/quality-gate.md' feature-delivery
contains "$WF/feature-delivery/phase-4-db-api.yaml" 'execution: {mode: parallel, join: all}' feature-delivery
contains "$WF/feature-delivery/phase-4-db-api.yaml" 'exit_artifacts: [design/ddl.md]' feature-delivery
contains "$WF/feature-delivery/phase-4-db-api.yaml" 'exit_artifacts: [design/api-contract.md]' feature-delivery
contains "$WF/feature-delivery/phase-5-lld.yaml" 'quality/gates/lld-design/quality-gate.md' feature-delivery
contains "$WF/feature-delivery/phase-6-plan.yaml" 'exit_artifacts: [plans/implementation-plan.md]' feature-delivery
contains "$WF/feature-delivery/phase-8-verify-archive.yaml" 'exit_artifacts: [quality/verification-report.md]' feature-delivery
contains "$WF/feature-delivery/phase-8-verify-archive.yaml" 'exit_artifacts: [archive/{date}-{task-id}/]' feature-delivery
parallel_group "$WF/feature-delivery/phase-7-code.yaml" feature-delivery

if (( failures > 0 )); then
    echo "Workflow smoke failed: $failures error(s)" >&2
    exit 1
fi
echo 'PASS bugfix/investigation: ONES-only stops after root cause'
echo 'PASS bugfix/fix: implementation -> fan-out/join -> gate -> verification -> archive'
echo 'PASS refactoring: repository context -> plan -> implementation -> quality -> archive'
echo 'PASS feature-delivery: 8 phases, DB/API parallel, design and implementation gates'
echo 'Workflow smoke passed: 3 workflows / 4 scenarios'
