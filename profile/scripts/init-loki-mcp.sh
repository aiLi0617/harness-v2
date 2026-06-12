#!/usr/bin/env bash
#
# Install Grafana loki-mcp and merge loki-mcp into Cursor MCP config.
#
# Usage:
#   bash init-loki-mcp.sh [--loki-url URL] [--mode docker|binary|auto] [project-path]
#
# Options:
#   --loki-url URL     Default Loki API (default: http://192.168.3.25:3100)
#   --mode MODE        docker | binary | auto (default: auto)
#   --skip-build       Only merge MCP config
#   -h, --help         Show help

set -euo pipefail

LOKI_URL="${LOKI_URL:-http://192.168.3.25:3100}"
MODE="auto"
SKIP_BUILD=false
PROJECT_PATH=""

usage() {
    sed -n '2,12p' "$0" | sed 's/^# \?//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --loki-url) LOKI_URL="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) PROJECT_PATH="$1"; shift ;;
    esac
done

IMAGE_NAME="loki-mcp-server:latest"
REPO_URL="https://github.com/grafana/loki-mcp.git"
REPO_TAG="v0.6.0"
CACHE_REPO="${TMPDIR:-/tmp}/loki-mcp"

if [[ "$(uname -s)" == "Darwin" ]]; then
    BINARY_DIR="$HOME/Library/Application Support/loki-mcp"
else
    BINARY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/loki-mcp"
fi
BINARY_PATH="$BINARY_DIR/loki-mcp-server"

step() { echo ""; echo "==> $1"; }

docker_ready() {
    command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

ensure_repo() {
    if [[ ! -d "$CACHE_REPO/.git" ]]; then
        echo "  Cloning $REPO_URL ($REPO_TAG) ..."
        git clone --depth 1 --branch "$REPO_TAG" "$REPO_URL" "$CACHE_REPO"
    fi
}

build_docker() {
    ensure_repo
    echo "  Building Docker image $IMAGE_NAME ..."
    docker build -t "$IMAGE_NAME" "$CACHE_REPO"
}

build_binary() {
    command -v go >/dev/null 2>&1 || { echo "Go not found" >&2; exit 1; }
    ensure_repo
    mkdir -p "$BINARY_DIR"
    echo "  Building binary -> $BINARY_PATH ..."
    (cd "$CACHE_REPO" && go build -o "$BINARY_PATH" ./cmd/server)
    chmod +x "$BINARY_PATH"
}

merge_mcp() {
    local target="$1"
    local mode="$2"
    [[ -f "$target" ]] || { echo "  [SKIP] Not found: $target"; return; }

    python3 - "$target" "$LOKI_URL" "$mode" "$IMAGE_NAME" "$BINARY_PATH" <<'PY'
import json
import sys

path, loki_url, mode, image, binary = sys.argv[1:6]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

env = {"LOKI_URL": loki_url}
if mode == "docker":
    block = {
        "command": "docker",
        "args": [
            "run", "--rm", "-i",
            "-e", "LOKI_URL",
            "-e", "LOKI_ORG_ID",
            "-e", "LOKI_USERNAME",
            "-e", "LOKI_PASSWORD",
            "-e", "LOKI_TOKEN",
            image,
        ],
        "env": env,
    }
else:
    block = {"command": binary, "args": [], "env": env}

data.setdefault("mcpServers", {})["loki-mcp"] = block
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"  [OK] Updated loki-mcp in {path}")
PY
}

echo "Loki MCP init (grafana/loki-mcp)"
echo "  LOKI_URL: $LOKI_URL"

INSTALL_MODE="$MODE"
if [[ "$MODE" == "auto" ]]; then
    if docker_ready; then INSTALL_MODE="docker"; else INSTALL_MODE="binary"; fi
    echo "  Mode: auto -> $INSTALL_MODE"
fi

if [[ "$SKIP_BUILD" != true ]]; then
    step "Build loki-mcp ($INSTALL_MODE)"
    if [[ "$INSTALL_MODE" == "docker" ]]; then
        build_docker || {
            echo "  Docker build failed, trying Go binary ..."
            INSTALL_MODE="binary"
            build_binary
        }
    else
        build_binary
    fi
else
    echo "  [SKIP] Build skipped (--skip-build)"
fi

step "Merge Cursor MCP config"
USER_MCP="$HOME/.cursor/mcp.json"
merge_mcp "$USER_MCP" "$INSTALL_MODE"

if [[ -n "$PROJECT_PATH" && -d "$PROJECT_PATH" ]]; then
    merge_mcp "$(cd "$PROJECT_PATH" && pwd)/.cursor/mcp.json" "$INSTALL_MODE"
fi

echo ""
echo "Done. Restart Cursor and verify loki-mcp in MCP panel."
