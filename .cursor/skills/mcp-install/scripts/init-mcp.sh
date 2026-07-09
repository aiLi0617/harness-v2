#!/usr/bin/env bash
# 根据 workspace + mcp-registry 生成/合并 Cursor MCP 配置
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
  --profile NAME     dev | sit | pre
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
INSTALL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SWITCH_ROOT="$(cd "$INSTALL_ROOT/../mcp-switch" && pwd)"
PROJECT_ROOT="$(cd "$INSTALL_ROOT/../../../.." && pwd)"
CONFIGURATOR="$SWITCH_ROOT/scripts/mcp-configurator.py"
WORKSPACE="$SWITCH_ROOT/mcp.workspace.json"
LEGACY_WORKSPACE="${HOME}/.cursor/mcp.workspace.json"

if [[ ! -f "$WORKSPACE" && -f "$LEGACY_WORKSPACE" ]]; then
  echo "Using legacy $LEGACY_WORKSPACE — copy to $WORKSPACE to finish migration" >&2
  WORKSPACE="$LEGACY_WORKSPACE"
fi

PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  PYTHON=python
fi

if [[ ! -f "$WORKSPACE" ]]; then
  echo "Missing $WORKSPACE. Run bootstrap-mcp.ps1 or ensure mcp.workspace.json exists (clone repo)." >&2
  exit 1
fi

ARGS=(--project-root "$PROJECT_ROOT" --skill-root "$SWITCH_ROOT" --target "$TARGET" --mode "$MODE" --workspace-config "$WORKSPACE")

if $LIST; then
  exec "$PYTHON" "$CONFIGURATOR" "${ARGS[@]}" --list-profiles
fi

[[ -n "$PROFILE" ]] && ARGS+=(--profile "$PROFILE")
[[ -n "$SERVERS" ]] && ARGS+=(--servers "$SERVERS")
$DRY_RUN && ARGS+=(--dry-run)
$FORCE && ARGS+=(--force)

exec "$PYTHON" "$CONFIGURATOR" "${ARGS[@]}"
