#!/usr/bin/env bash
#
# 将 Harness Cursor 配置链接到目标业务项目，并复制 MCP 工作区模板。
#
# 软链（目录）: .cursor/agents, rules, skills, workflows, scripts
# 软链（文件）: .cursor/AGENTS.md, .cursor/CLAUDE.md
# 本地目录: docs/artifacts/work, docs/artifacts/archive
# 复制（独立）: .cursor/mcp-workspace/mcp.workspace.json, mcp.workspace.secrets.json
#
# 用法:
#   ./link-cursor-config.sh <目标项目路径>
#   bash link-cursor-config.sh <目标项目路径>
#   ./link-cursor-config.sh -f <目标项目路径>
#
# 示例:
#   ./link-cursor-config.sh ~/Work/Project/Java/broker
#   ./link-cursor-config.sh -f ~/Work/Project/Java/broker

set -euo pipefail

ensure_harness_script_permissions() {
    local root="$1"
    local script
    local rel
    local fixed=0

    for script in "$root/link-cursor-config.sh" "$root"/.cursor/scripts/*.sh; do
        [[ -f "$script" ]] || continue
        if [[ ! -x "$script" ]]; then
            chmod +x "$script"
            rel="${script#"$root"/}"
            echo "  [OK]   设置可执行: $rel"
            fixed=$((fixed + 1))
        fi
    done

    if [[ "$fixed" -gt 0 ]]; then
        echo "  已为 $fixed 个 shell 脚本补全可执行权限（macOS/Linux git clone 常见丢失 +x）"
    fi
}

SOURCE_EARLY="$(cd "$(dirname "$0")" && pwd)"
ensure_harness_script_permissions "$SOURCE_EARLY"

FORCE=false
if [[ "${1:-}" == "-f" ]]; then
    FORCE=true
    shift
fi

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    echo "用法: $0 [-f] <目标项目路径>"
    exit 1
fi

SOURCE="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -d "$SOURCE" ]]; then
    echo "错误: 源目录不存在: $SOURCE" >&2
    exit 1
fi
if [[ ! -d "$TARGET" ]]; then
    echo "错误: 目标目录不存在: $TARGET" >&2
    exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

if [[ "$TARGET" == "$SOURCE" ]]; then
    echo "错误: 目标目录不能是 Harness 源目录本身" >&2
    exit 1
fi
case "$TARGET/" in
    "$SOURCE/"*)
        echo "错误: 目标目录不能位于 Harness 源目录内部，避免产生循环链接: $TARGET" >&2
        exit 1
        ;;
esac

LINK_DIRS=(
    ".cursor/agents"
    ".cursor/rules"
    ".cursor/skills"
    ".cursor/workflows"
    ".cursor/scripts"
)

LOCAL_DIRS=(
    "docs/artifacts/work"
    "docs/artifacts/archive"
)

LINK_FILES=(
    ".cursor/AGENTS.md"
    ".cursor/CLAUDE.md"
)

success=0
skip=0
fail=0

remove_existing() {
    local dst_path="$1"
    if [[ ! -e "$dst_path" && ! -L "$dst_path" ]]; then
        return 0
    fi
    if $FORCE; then
        rm -rf "$dst_path"
        echo "  移除已有项: $dst_path"
        return 0
    fi
    return 1
}

echo ""
echo "=== 软链目录 ==="
for rel in "${LINK_DIRS[@]}"; do
    src_path="$SOURCE/$rel"
    dst_path="$TARGET/$rel"

    if [[ ! -e "$src_path" ]]; then
        echo "  [SKIP] $rel — 源不存在"
        ((++skip))
        continue
    fi

    dst_parent="$(dirname "$dst_path")"
    mkdir -p "$dst_parent"

    if [[ -e "$dst_path" || -L "$dst_path" ]]; then
        if ! remove_existing "$dst_path"; then
            echo "  [SKIP] $rel — 已存在（使用 -f 覆盖）"
            ((++skip))
            continue
        fi
    fi

    if ln -s "$src_path" "$dst_path" 2>/dev/null; then
        echo "  [OK]   $rel (symlink)"
        echo "         $src_path -> $dst_path"
        ((++success))
    else
        echo "  [FAIL] $rel" >&2
        ((++fail))
    fi
done

echo ""
echo "=== 软链文件 ==="
for rel in "${LINK_FILES[@]}"; do
    src_path="$SOURCE/$rel"
    dst_path="$TARGET/$rel"

    if [[ ! -f "$src_path" ]]; then
        echo "  [SKIP] $rel — 源不存在"
        ((++skip))
        continue
    fi

    dst_parent="$(dirname "$dst_path")"
    mkdir -p "$dst_parent"

    if [[ -e "$dst_path" || -L "$dst_path" ]]; then
        if ! remove_existing "$dst_path"; then
            echo "  [SKIP] $rel — 已存在（使用 -f 覆盖）"
            ((++skip))
            continue
        fi
    fi

    if ln -s "$src_path" "$dst_path" 2>/dev/null; then
        echo "  [OK]   $rel (symlink)"
        echo "         $src_path -> $dst_path"
        ((++success))
    else
        echo "  [FAIL] $rel" >&2
        ((++fail))
    fi
done

echo ""
echo "=== 初始化目标项目本地目录 ==="
for rel in "${LOCAL_DIRS[@]}"; do
    dst_path="$TARGET/$rel"
    if [[ ! -d "$dst_path" ]]; then
        mkdir -p "$dst_path"
        echo "  [OK]   $rel (local, 目标项目独立目录)"
        ((++success))
    else
        echo "  [OK]   $rel (local, 已存在)"
    fi
done

echo ""
echo "=== 复制 MCP 工作区 ==="

mcp_workspace_dir="$TARGET/.cursor/mcp-workspace"
mcp_workspace_file="$mcp_workspace_dir/mcp.workspace.json"
mcp_secrets_file="$mcp_workspace_dir/mcp.workspace.secrets.json"
workspace_template="$SOURCE/.cursor/skills/mcp-switch/mcp.workspace.link-template.json"
secrets_template="$SOURCE/.cursor/skills/mcp-switch/mcp.workspace.secrets.example.json"

mkdir -p "$mcp_workspace_dir"

if [[ -f "$workspace_template" ]]; then
    if [[ -f "$mcp_workspace_file" ]] && ! $FORCE; then
        echo "  [SKIP] .cursor/mcp-workspace/mcp.workspace.json — 已存在（使用 -f 覆盖）"
        ((++skip))
    else
        normalized_target="${TARGET//\\//}"
        sed "s|__TARGET_PROJECT_PATH__|$normalized_target|g" "$workspace_template" > "$mcp_workspace_file"
        echo "  [OK]   .cursor/mcp-workspace/mcp.workspace.json (copy)"
        ((++success))
    fi
else
    echo "  [SKIP] .cursor/mcp-workspace/mcp.workspace.json — 模板不存在"
    ((++skip))
fi

if [[ -f "$secrets_template" ]]; then
    if [[ -f "$mcp_secrets_file" ]] && ! $FORCE; then
        echo "  [SKIP] .cursor/mcp-workspace/mcp.workspace.secrets.json — 已存在（使用 -f 覆盖）"
        ((++skip))
    else
        cp "$secrets_template" "$mcp_secrets_file"
        echo "  [OK]   .cursor/mcp-workspace/mcp.workspace.secrets.json (copy)"
        ((++success))
    fi
else
    echo "  [SKIP] .cursor/mcp-workspace/mcp.workspace.secrets.json — 模板不存在"
    ((++skip))
fi

echo ""
echo "完成: 成功 $success, 跳过 $skip, 失败 $fail"

echo ""
echo "  [提示] MCP 初始化"
echo "    1. 编辑 .cursor/mcp-workspace/mcp.workspace.json"
echo "    2. 编辑 .cursor/mcp-workspace/mcp.workspace.secrets.json"
echo "    3. bash .cursor/skills/mcp-install/scripts/init-mcp.sh --profile dev"
echo "    日常切换: powershell -File .cursor/skills/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev"

echo ""
echo "  [提示] 可选：初始化 CodeGraph 索引"
echo "    bash \"$SOURCE/.cursor/scripts/init-codegraph.sh\" \"$TARGET\""

echo ""
ensure_harness_script_permissions "$SOURCE"

if [[ $fail -gt 0 ]]; then
    exit 1
fi
