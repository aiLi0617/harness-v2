#!/usr/bin/env bash
#
# 初始化 CodeGraph：全局 Cursor MCP + 业务项目索引（.codegraph/）
#
# 用法:
#   bash .cursor/scripts/init-codegraph.sh [项目路径]
#   bash init-codegraph.sh --accept-git-hooks /path/to/project
#
# 选项:
#   -h, --help              显示帮助
#   --skip-global-mcp       跳过用户级 Cursor MCP 安装
#   --skip-global-cli       跳过 npm 全局安装，全程 npx
#   --skip-index            init 时不加 -i
#   --force-reindex         强制全量重建索引
#   --accept-git-hooks      init 时自动接受 git hooks 安装提示
#
# 示例:
#   cd ~/Work/my-java-app && bash <harness>/init-codegraph.sh
#   bash init-codegraph.sh --accept-git-hooks ~/Work/my-java-app

set -euo pipefail

PROJECT_PATH=""
SKIP_GLOBAL_MCP=false
SKIP_GLOBAL_CLI=false
SKIP_INDEX=false
FORCE_REINDEX=false
ACCEPT_GIT_HOOKS=false

usage() {
    sed -n '2,18p' "$0" | sed 's/^# \?//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --skip-global-mcp)
            SKIP_GLOBAL_MCP=true
            shift
            ;;
        --skip-global-cli)
            SKIP_GLOBAL_CLI=true
            shift
            ;;
        --skip-index)
            SKIP_INDEX=true
            shift
            ;;
        --force-reindex)
            FORCE_REINDEX=true
            shift
            ;;
        --accept-git-hooks)
            ACCEPT_GIT_HOOKS=true
            shift
            ;;
        -*)
            echo "未知选项: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            PROJECT_PATH="$1"
            shift
            ;;
    esac
done

if [[ -z "$PROJECT_PATH" ]]; then
    PROJECT_PATH="$(pwd)"
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "错误: 项目目录不存在: $PROJECT_PATH" >&2
    exit 1
fi

PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

step() {
    echo ""
    echo "==> $1"
}

run_codegraph() {
    if [[ -n "$CG_CMD" ]]; then
        "$CG_CMD" "$@"
    else
        npx -y @colbymchenry/codegraph "$@"
    fi
}

ensure_invoker() {
    if [[ "$SKIP_GLOBAL_CLI" == true ]]; then
        CG_CMD=""
        return
    fi
    if command -v codegraph >/dev/null 2>&1; then
        CG_CMD="codegraph"
        return
    fi
    echo "  未检测到全局 codegraph，正在 npm i -g @colbymchenry/codegraph ..."
    npm i -g @colbymchenry/codegraph
    if command -v codegraph >/dev/null 2>&1; then
        CG_CMD="codegraph"
    else
        CG_CMD=""
    fi
}

merge_mcp_codegraph() {
    local mcp_json="$PROJECT_PATH/.cursor/mcp.json"
    local mcp_template="$PROJECT_PATH/.cursor/mcp/mcp-template.json"

    if [[ ! -f "$mcp_template" ]]; then
        echo "  [SKIP] 无 .cursor/mcp/mcp-template.json（请先运行 link-cursor-config）"
        return
    fi

    if [[ ! -f "$mcp_json" ]]; then
        echo "  [WARN] 未找到 .cursor/mcp.json，请先复制 mcp-template 并填入密钥"
        echo "         cp .cursor/mcp/mcp-template.json .cursor/mcp.json"
        return
    fi

    if grep -q '"codegraph-mcp"' "$mcp_json"; then
        echo "  [OK]   .cursor/mcp.json 已包含 codegraph-mcp"
        return
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "  [WARN] 未找到 python3，无法自动合并 codegraph-mcp，请手动从 mcp-template.json 复制"
        return
    fi

    python3 - "$mcp_json" "$mcp_template" <<'PY'
import json
import sys

mcp_path, template_path = sys.argv[1], sys.argv[2]
with open(mcp_path, encoding="utf-8") as f:
    mcp = json.load(f)
with open(template_path, encoding="utf-8") as f:
    template = json.load(f)

block = template.get("mcpServers", {}).get("codegraph-mcp")
if not block:
    print("  [WARN] mcp-template.json 中未找到 codegraph-mcp 段")
    sys.exit(0)

servers = mcp.setdefault("mcpServers", {})
servers["codegraph-mcp"] = block
with open(mcp_path, "w", encoding="utf-8") as f:
    json.dump(mcp, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("  [OK]   已向 .cursor/mcp.json 合并 codegraph-mcp")
PY
}

echo "CodeGraph 初始化"
echo "  项目路径: $PROJECT_PATH"

if ! command -v npx >/dev/null 2>&1; then
    echo "错误: 未找到 npx。请安装 Node.js，或使用官方 install.sh:" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh" >&2
    exit 1
fi

CG_CMD=""
ensure_invoker

if [[ "$SKIP_GLOBAL_MCP" != true ]]; then
    step "配置用户级 Cursor MCP"
    run_codegraph install --target=cursor --yes
    echo "  完成后请重启 Cursor。"
fi

step "检查项目 MCP 配置（codegraph-mcp）"
merge_mcp_codegraph

step "初始化项目索引"
cd "$PROJECT_PATH"

if [[ "$FORCE_REINDEX" == true && -d .codegraph ]]; then
    echo "  强制全量重建索引 ..."
    run_codegraph index --force
elif [[ -d .codegraph ]]; then
    echo "  [SKIP] 已存在 .codegraph/，跳过 init（使用 --force-reindex 强制重建）"
    run_codegraph sync
else
    init_args=(init)
    if [[ "$SKIP_INDEX" != true ]]; then
        init_args+=(-i)
    fi
    if [[ "$ACCEPT_GIT_HOOKS" == true ]]; then
        echo "  将尝试自动接受 git hooks 安装提示 ..."
        yes | run_codegraph "${init_args[@]}"
    else
        run_codegraph "${init_args[@]}"
        echo "  若出现 git hooks 提示，建议选择 Yes（切分支/merge 后自动 sync）。"
    fi
fi

step "索引状态"
run_codegraph status

echo ""
echo "完成。请重启 Cursor，并在业务项目中确认 .codegraph/ 已生成。"
