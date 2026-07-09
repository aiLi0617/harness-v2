---
name: mcp-dbx
description: >-
  通过 DBX MCP 访问 MySQL/Redis/ES，连接来自 DBX 桌面端（dev/sit/pre × broker/cloud/b2c）。
  在 workspace dataAccess=dbx-mcp 且于 Cursor 设置中手动启用本 skill 时使用。
  不用于 dataAccess=profile-mcp（改用 mcp-db）、与 mcp-dbx 互斥的 profile MCP 模式、或仅需 mcp-switch 切换 Loki/XXL-Job 等非数据层服务时。
disable-model-invocation: true
---

# DBX MCP（mcp-dbx）

> **默认禁用**（`disable-model-invocation: true`）。workspace `dataAccess=dbx-mcp` 时在 Cursor 设置里**手动启用**本 skill。

通过 Cursor MCP **`dbx`** 访问 MySQL / Redis / ES，连接来自 **DBX 桌面端**（dev / sit / pre × broker / cloud / b2c）。

> **与 mcp-switch / mcp-db 的分工**：
> - **本 skill（mcp-dbx）**：数据层 MySQL/Redis/ES → MCP `dbx` + 连接名
> - **[mcp-db](../mcp-db/SKILL.md)**：数据层 MySQL/Redis/ES → profile MCP，随 dev/sit/pre 切换
> - **[mcp-switch](../mcp-switch/SKILL.md)**：Loki / XXL-Job / Nacos / RocketMQ 等 profile 切换
>
> **互斥**：`mcp-dbx` 与 `mcp-db` 对 MySQL/Redis/ES **二选一**（mcp-install 自动处理）。

## 何时启用

| 模式 | 启用 skill | workspace 数据访问 |
|------|-----------|-------------------|
| **DBX MCP** | `mcp-dbx` | `dataAccess=dbx-mcp`；`fixedServers` 含 `dbx`；profile **无** mysql/redis/es |
| **Profile MCP** | `mcp-db` + `mcp-switch` | `dataAccess=profile-mcp`；profile 含 mysql/redis/es；**无** `dbx` |

## 安装（mcp-install）

```powershell
# 只装 DBX MCP（自动剔除 profile 中的 mysql/redis/es）
.cursor/skills/shared/mcp-install/scripts/bootstrap-mcp.ps1 -Servers dbx -NonInteractive

# DBX + 日志等（不要同时选 mysql-mcp/redis-mcp）
.cursor/skills/shared/mcp-install/scripts/bootstrap-mcp.ps1 -Servers dbx,loki-mcp -NonInteractive
```

改 **`mcp-switch/mcp.workspace.json`** 的 `dataAccess`，再跑 `switch-all-mcp-profiles.ps1`。

## 连接命名

```
{projectId}-{env}[-{variant}]-{type}
```

| 段 | 取值 |
|----|------|
| projectId | `broker` / `cloud` / `b2c` |
| env | `dev` / `sit` / `pre` |
| variant | `tmp` / `log`（可选） |
| type | `mysql` / `mysql-log` / `redis` / `es` |

示例：`broker-dev-mysql`、`broker-sit-redis`、`cloud-pre-es`

完整对照表：[reference.md](reference.md)

## 环境 / 项目切换

**不换 mcp-switch profile 来换库**——换 **连接名**：

| 目标 | 连接名示例 |
|------|-----------|
| 经纪商 SIT MySQL | `broker-sit-mysql` |
| 云商 dev Redis | `cloud-dev-redis` |
| B2C pre ES | `b2c-pre-es` |

当前 `activeProfile`（dev/sit/pre）仅影响 Loki、XXL-Job 等 **profile MCP**；查库时 Agent 根据任务选用上表连接名。

## Agent 工具

| 任务 | 方式 |
|------|------|
| MySQL | MCP `dbx`（连接名如 `broker-sit-mysql`） |
| Redis | MCP `dbx`（如 `broker-dev-redis`） |
| ES | MCP `dbx`（如 `cloud-dev-es`） |
| 日志 | MCP `{projectId}-loki-mcp`（mcp-switch） |
| 切换 Loki 等环境 | `switch-all-mcp-profiles.ps1` |

**禁止**（`dataAccess=dbx-mcp` 时）：

- 调用 `{projectId}-mysql-mcp`、`redis-mcp`、`elasticsearch-mcp`
- 在 workspace profile 中保留 mysql/redis/es MCP

## workspace 字段

```json
{
  "dataAccess": "dbx-mcp",
  "fixedServers": ["codegraph", "ONES", "dbx"],
  "projects": {
    "broker": {
      "profiles": {
        "dev": {
          "servers": ["loki-mcp", "xxl-job-mcp", "nacos-mcp-router", "rocketmq-mcp"]
        }
      }
    }
  }
}
```

## 前置条件

1. `npm i -g @dbx-app/mcp-server`
2. DBX 桌面端已配置连接（见 reference 命名）
3. `mcp.workspace.json` → `tools.NODE_BIN`、`tools.DBX_MCP_ENTRY`
4. mcp-switch 生成 `~/.cursor/mcp.json` 且含 `dbx` 条目

## 相关

- 安装编排：[mcp-install](../mcp-install/SKILL.md)
- Profile MCP 数据层（互斥）：[mcp-db](../mcp-db/SKILL.md)
- 环境切换（非数据 MCP）：[mcp-switch](../mcp-switch/SKILL.md)
- 路由规则：`.cursor/rules/memory/data-access-backend.mdc`
- DBX CLI（旧路径）：[dbx-data-access](../dbx-data-access/SKILL.md)
