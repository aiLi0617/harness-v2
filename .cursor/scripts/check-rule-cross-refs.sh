#!/usr/bin/env bash
# Check leaf .mdc rules for cross-file references to other .mdc files
# Usage (recommended, no +x required):
#   bash .cursor/scripts/check-rule-cross-refs.sh
# Usage (after chmod +x or link-cursor-config.sh):
#   .cursor/scripts/check-rule-cross-refs.sh
# Exit code: 0=pass, 1=violations found

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_ROOT="${1:-$(cd "$SCRIPT_DIR/../rules" && pwd)}"

ALLOWLIST=(
  "orchestration/coding-standards-loader.mdc"
  "feedback/correction-detection.mdc"
  "feedback/java-edit-self-check.mdc"
  "feedback/rule-cross-ref-guard.mdc"
)

is_allowlisted() {
  local rel="$1"
  local allowed
  for allowed in "${ALLOWLIST[@]}"; do
    if [[ "$rel" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

test_cross_ref_line() {
  local line="$1"
  local stem="$2"

  if [[ "$line" =~ [\`\']+([a-zA-Z0-9_-]+)\.mdc[\`\']+ ]]; then
    if [[ "${BASH_REMATCH[1]}" != "$stem" ]]; then
      printf '%s' "backtick .mdc"
      return 0
    fi
  fi

  if [[ "$line" =~ rules/(memory|feedback|orchestration|execution)/[a-zA-Z0-9_-]+\.mdc ]]; then
    printf '%s' "rules/ path"
    return 0
  fi

  if [[ "$line" =~ (见|详见|配合|参见|参考)[[:space:]]*[\`\']?[a-zA-Z0-9_-]+\.mdc ]]; then
    printf '%s' "see xxx.mdc"
    return 0
  fi

  if [[ "$line" =~ 与[[:space:]]*[\`\']?[a-zA-Z0-9_-]+\.mdc ]]; then
    printf '%s' "with xxx.mdc"
    return 0
  fi

  return 1
}

violations=0
file_count=0
violation_log="$(mktemp)"
trap 'rm -f "$violation_log"' EXIT

while IFS= read -r -d '' file; do
  file_count=$((file_count + 1))
  rel="${file#"$RULES_ROOT"/}"
  rel="${rel//\\//}"

  if is_allowlisted "$rel"; then
    continue
  fi

  stem="$(basename "$file" .mdc)"
  in_code_fence=0
  line_num=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    if [[ "$line" =~ ^[[:space:]]*\`\`\` ]]; then
      if [[ "$in_code_fence" -eq 0 ]]; then
        in_code_fence=1
      else
        in_code_fence=0
      fi
      continue
    fi

    if [[ "$in_code_fence" -eq 1 ]]; then
      continue
    fi

    pattern="$(test_cross_ref_line "$line" "$stem" || true)"
    if [[ -n "$pattern" ]]; then
      violations=$((violations + 1))
      trimmed="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      {
        echo "  $rel:$line_num [$pattern]"
        echo "    $trimmed"
      } >> "$violation_log"
    fi
  done < "$file"
done < <(find "$RULES_ROOT" -name '*.mdc' -type f -print0)

if [[ "$violations" -eq 0 ]]; then
  echo "OK: no cross-file .mdc references in leaf rules ($file_count files scanned)."
  exit 0
fi

echo "FAIL: found $violations cross-file .mdc reference(s):"
cat "$violation_log"
echo ""
echo "Fix: inline the constraint or add a loader scene entry. See feedback/rule-cross-ref-guard.mdc."
exit 1
