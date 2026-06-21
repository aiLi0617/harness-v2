#!/usr/bin/env bash
# 根据 profile + mcp-registry 生成/合并 Cursor MCP 配置
set -euo pipefail

TARGET="user"
MODE="single"
PROFILE=""
SERVERS=""
DRY_RUN=false
FORCE=false
LIST=false

usage() {
  cat <<'EOF'
Usage:
  init-mcp.sh [user|project] [options]

Options:
  --profile NAME     dev | pre (dev 含 sit)
  --mode MODE        single (default) | unified
  --servers A,B,C    override server list
  --dry-run
  --force
  --list-profiles
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    user|project) TARGET="$1"; shift ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --servers) SERVERS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    --list-profiles) LIST=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SKILL_ROOT/../../../.." && pwd)"
CONFIGURATOR="$SCRIPT_DIR/mcp-configurator.py"

PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  PYTHON=python
fi

ARGS=(--project-root "$PROJECT_ROOT" --skill-root "$SKILL_ROOT" --target "$TARGET" --mode "$MODE")

if $LIST; then
  exec "$PYTHON" "$CONFIGURATOR" "${ARGS[@]}" --list-profiles
fi

[[ -n "$PROFILE" ]] && ARGS+=(--profile "$PROFILE")
[[ -n "$SERVERS" ]] && ARGS+=(--servers "$SERVERS")
$DRY_RUN && ARGS+=(--dry-run)
$FORCE && ARGS+=(--force)

exec "$PYTHON" "$CONFIGURATOR" "${ARGS[@]}"
