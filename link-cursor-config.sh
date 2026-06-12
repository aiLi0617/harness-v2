#!/usr/bin/env bash
#
# 将本项目的 Cursor 配置（agents、rules、skills、workflows、scripts、AGENTS.md、CLAUDE.md、mcp/mcp-template.json）
# 软连接/复制到指定目标项目目录。
#
# 用法:
#   ./link-cursor-config.sh <目标项目路径>
#   bash link-cursor-config.sh <目标项目路径>          # 无 +x 时也可
#   ./link-cursor-config.sh -f <目标项目路径>          # 强制覆盖已有项
#
# 示例:
#   ./link-cursor-config.sh ~/Work/Project/Java/456
#   ./link-cursor-config.sh -f ~/Work/Project/Java/456

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

# git clone 后可能无 +x；先修复 harness 源目录内脚本，再执行链接
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

ITEMS=(
    ".cursor/agents:dir"
    ".cursor/rules:dir"
    ".cursor/skills:dir"
    ".cursor/workflows:dir"
    ".cursor/scripts:dir"
    ".cursor/AGENTS.md:file"
    ".cursor/CLAUDE.md:file"
    "docs:dir"
    # 项目特有内容位于 profile/ 目录，不自动链接到目标项目。
    # 如需为目标项目接入 profile 内容，请手动复制 profile/ 中的文件。
)

success=0
skip=0
fail=0

for entry in "${ITEMS[@]}"; do
    rel="${entry%%:*}"
    src_path="$SOURCE/$rel"
    dst_path="$TARGET/$rel"

    if [[ ! -e "$src_path" ]]; then
        echo "  [WARN] 源不存在，跳过: $rel"
        ((skip++))
        continue
    fi

    dst_parent="$(dirname "$dst_path")"
    if [[ ! -d "$dst_parent" ]]; then
        mkdir -p "$dst_parent"
        echo "  创建父目录: $dst_parent"
    fi

    if [[ -e "$dst_path" || -L "$dst_path" ]]; then
        if [[ -L "$dst_path" ]]; then
            if $FORCE; then
                rm "$dst_path"
                echo "  移除旧软连接: $dst_path"
            else
                echo "  [WARN] 已存在软连接，跳过（使用 -f 覆盖）: $rel"
                ((skip++))
                continue
            fi
        elif $FORCE; then
            rm -rf "$dst_path"
            echo "  移除已有项: $dst_path"
        else
            echo "  [WARN] 目标已存在且非软连接，跳过（使用 -f 覆盖）: $rel"
            ((skip++))
            continue
        fi
    fi

    if ln -s "$src_path" "$dst_path" 2>/dev/null; then
        echo "  [OK]   $rel"
        echo "         $src_path -> $dst_path"
        ((success++))
    else
        echo "  [FAIL] $rel" >&2
        ((fail++))
    fi
done

# MCP 模板单独处理：复制而非链接（每个项目需独立配置密钥）
mcp_template_src="$SOURCE/.cursor/mcp/mcp-template.json"
mcp_template_dst="$TARGET/.cursor/mcp/mcp-template.json"
mcp_json_dst="$TARGET/.cursor/mcp.json"

if [[ -f "$mcp_template_src" ]]; then
    mcp_parent="$(dirname "$mcp_template_dst")"
    if [[ ! -d "$mcp_parent" ]]; then
        mkdir -p "$mcp_parent"
    fi

    if [[ -e "$mcp_template_dst" ]] && ! $FORCE; then
        echo "  [WARN] MCP 模板已存在，跳过（使用 -f 覆盖）: .cursor/mcp/mcp-template.json"
        ((skip++))
    else
        cp "$mcp_template_src" "$mcp_template_dst"
        echo "  [OK]   .cursor/mcp/mcp-template.json（复制）"
        ((success++))
    fi

    if [[ ! -f "$mcp_json_dst" ]]; then
        echo ""
        echo "  [提示] 请复制 .cursor/mcp/mcp-template.json 为 .cursor/mcp.json 并填入实际密钥"
    fi
else
    echo "  [WARN] 源不存在，跳过: .cursor/mcp/mcp-template.json"
    ((skip++))
fi

echo ""
echo "  [提示] 可选：在业务项目根目录初始化 CodeGraph 索引"
echo "    bash \"$SOURCE/.cursor/scripts/init-codegraph.sh\" \"$TARGET\""

echo ""
ensure_harness_script_permissions "$SOURCE"
echo ""
echo "完成: 成功 $success, 跳过 $skip, 失败 $fail"

if [[ $fail -gt 0 ]]; then
    exit 1
fi
