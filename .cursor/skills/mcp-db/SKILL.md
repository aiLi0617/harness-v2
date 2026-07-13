---
name: mcp-db
description: >-
  通过分环境 profile MCP（mysql-mcp、redis-mcp、elasticsearch-mcp）访问 MySQL/Redis/ES，随 dev/sit/pre 切换。
  在 workspace dataAccess=profile-mcp 且于 Cursor 设置中手动启用本 skill 时使用；需配合 mcp-switch。
  不用于 dataAccess=dbx-mcp（改用 mcp-dbx）、与 mcp-db 互斥的 dbx 模式、或未配置 mcp-switch 时。
disable-model-invocation: true
---

# Profile 数据 MCP（mcp-db）

> **默认禁用**（`disable-model-invocation: true`）。workspace `dataAccess=profile-mcp` 时在 Cursor 设置里**手动启用**本 skill。

通过 **分环境 profile MCP** 访问 MySQL / Redis / ES：`mysql-mcp`、`redis-mcp`、`elasticsearch-mcp` 写入 workspace 各 profile，由 **mcp-switch** 随 dev/sit/pre 切换连接参数。

> **与 mcp-dbx 互斥**：启用 **[mcp-dbx](../mcp-dbx/SKILL.md)** 时 workspace **不得**含本 skill 的 profile MCP；`dataAccess=profile-mcp` 时使用本 skill。

## 何时启用

| 模式 | 启用 skill | workspace |
|------|-----------|-----------|
| **Profile MCP** | `mcp-db` + `mcp-switch` | `dataAccess=profile-mcp`；profile 含 mysql/redis/es；`fixedServers` **无** `dbx` |
| **DBX MCP** | `mcp-dbx` | `dataAccess=dbx-mcp`；见 mcp-dbx |

## 安装（mcp-install）

```powershell
# 只装 MySQL profile MCP
.cursor/skills/mcp-install/scripts/init-mcp.ps1 -Servers mysql-mcp

# 常用：日志 + 库
.cursor/skills/mcp-install/scripts/init-mcp.ps1 `
  -Servers loki-mcp,mysql-mcp,redis-mcp
```

**不要**与 `dbx` 同选；若同选，安装脚本会剔除 mysql/redis/es 并启用 dbx 模式。

改 **`mcp-switch/mcp.workspace.json`** → `dataAccess: profile-mcp`，再跑 `switch-all-mcp-profiles.ps1`。

## MCP ID 与 Agent 工具

| 数据类型 | registry ID | Cursor 工具名（多项目） |
|----------|-------------|------------------------|
| MySQL | `mysql-mcp` | `{projectId}-mysql-mcp` → `mysql_query` |
| Redis | `redis-mcp` | `{projectId}-redis-mcp` |
| ES | `elasticsearch-mcp` | `{projectId}-elasticsearch-mcp` |

`projectId`：`broker` / `cloud` / `b2c`（与 mcp-switch workspace 一致）。

## 环境切换

换 dev/sit/pre **必须**跑 mcp-switch（与 mcp-dbx 换连接名不同）：

```powershell
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 sit
```

切换后 Reload Window；MySQL host、REDIS_URL、ES_URL 等来自对应 profile 的 env + secrets。

## 配置要点

| MCP | 密钥 / env | 说明 |
|-----|------------|------|
| mysql-mcp | `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASS`, `MYSQL_DB` | `MYSQL_DB` 留空 = 多库 |
| redis-mcp | `REDIS_URL` | 完整 URL，密码勿 URL 编码 |
| elasticsearch-mcp | `ES_URL`, `ES_API_KEY` 或用户名密码 | 默认未在模板全 profile 启用 |

详情：[reference.md](reference.md)

## workspace 示例

```json
{
  "dataAccess": "profile-mcp",
  "fixedServers": ["codegraph", "ONES"],
  "projects": {
    "broker": {
      "profiles": {
        "dev": {
          "servers": ["loki-mcp", "mysql-mcp", "redis-mcp", "xxl-job-mcp"]
        }
      }
    }
  }
}
```

## 前置条件

1. Node.js 20+（mysql-mcp、elasticsearch-mcp 经 npx）
2. uv / uvx（redis-mcp）
3. `mcp.workspace.secrets.json` 中各 profile 密钥已填
4. mcp-switch 已生成 `~/.cursor/mcp.json`

## 相关

- 安装编排：`mcp-install/scripts/init-mcp.*`
- DBX MCP（互斥）：[mcp-dbx](../mcp-dbx/SKILL.md)
- 环境切换：[mcp-switch](../mcp-switch/SKILL.md)
- 路由规则：`.cursor/rules/memory/data-access-backend.mdc`
