---
name: mcp-switch
description: >-
  MCP environment switching (dev/sit/pre) for broker/cloud/b2c.
  Configure mcp.workspace.json + secrets; run switch-all-mcp-profiles.
disable-model-invocation: true
---

# MCP 环境切换（mcp-switch）

## 配置文件（仅 2 个）

| 文件 | 作用 |
|------|------|
| **[mcp.workspace.json](mcp.workspace.json)** | 环境、tools、项目 path、`dataAccess`、profile servers |
| **[mcp.workspace.secrets.json](mcp.workspace.secrets.json)** | 密码、REDIS_URL、Token 等 |

另 **[mcp-registry.json](mcp-registry.json)** 为 MCP 启动模板（一般不改）。

### `mcp.workspace.json` 关键字段

```json
{
  "activeProfile": "dev",
  "defaultProfile": "dev",
  "dataAccess": "profile-mcp",
  "dataLayerDbServers": ["mysql-mcp", "redis-mcp"],
  "tools": { "...": "本机路径" },
  "projects": { "broker": { "profiles": { "dev": { "servers": [...], "env": {...} } } } }
}
```

| 字段 | 取值 |
|------|------|
| `dataAccess` | `dbx-mcp` → MCP `dbx`；`profile-mcp` → `{projectId}-mysql-mcp` 等 |
| `dataLayerDbServers` | 切 `profile-mcp` 时恢复的数据 MCP |
| `activeProfile` / `defaultProfile` | 当前 / 默认 dev·sit·pre |

**切换：**

```powershell
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev
```

改 `dataAccess` 后同样跑上述命令。临时覆盖：`-DataAccess dbx-mcp`

## Agent 调用哪个 skill

**默认只开 `mcp-switch`**（`disable-model-invocation: true`）。数据层 skill **默认关闭**，按 `mcp.workspace.json` 的 `dataAccess` **手动启用其一**：

| `dataAccess` | 查 MySQL/Redis/ES 时启用 | 查库方式 | 环境切换 |
|--------------|--------------------------|----------|----------|
| `profile-mcp` | **[mcp-db](../mcp-db/SKILL.md)** | `{projectId}-mysql-mcp` 等 | `switch-all-mcp-profiles.ps1` 一并切数据 MCP |
| `dbx-mcp` | **[mcp-dbx](../mcp-dbx/SKILL.md)** | MCP `dbx` + 连接名 `broker-dev-mysql` | switch 只切 Loki 等；换库换连接名 |

Loki / XXL-Job / Nacos / RocketMQ：**始终走 mcp-switch**，不依赖 mcp-db / mcp-dbx。

安装编排：**[mcp-install](../mcp-install/SKILL.md)**（选 `dbx` 或 `mysql-mcp,redis-mcp` 时自动设 `dataAccess`）。

## 脚本

| 脚本 | 作用 |
|------|------|
| `switch-all-mcp-profiles.ps1` | 多项目统一切 dev/sit/pre |
| `switch-mcp-profile.ps1` | 单项目切换 |
| `switch-data-access.ps1` | 仅应用 `dataAccess` 并刷新 mcp.json |
| `show-project-mcp.ps1` | 查看 MCP 工具名映射 |

## 多项目工具名

| 模式 | MySQL 工具名 |
|------|-------------|
| profile-mcp | `broker-mysql-mcp` / `cloud-mysql-mcp` |
| dbx-mcp | `dbx` + 连接名 `broker-dev-mysql` |

详见 [reference.md](reference.md)。
