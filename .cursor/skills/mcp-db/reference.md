# Profile 数据 MCP — 环境变量与安装参考

> registry 定义见 [mcp-switch/mcp-registry.json](../mcp-switch/mcp-registry.json)（`layer: db`）。环境切换见 [mcp-switch/reference.md](../mcp-switch/reference.md)。

## MCP 清单（layer: db）

| ID | 安装 | 主要 env / secrets |
|----|------|-------------------|
| `mysql-mcp` | npx `@benborla29/mcp-server-mysql` | `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASS`, `MYSQL_DB` |
| `redis-mcp` | uvx `redis-mcp-server` | `REDIS_URL` |
| `elasticsearch-mcp` | npx `@elastic/mcp-server-elasticsearch` | `ES_URL`, `ES_API_KEY` 或 `ES_USERNAME`/`ES_PASSWORD` |

## MySQL

- `MYSQL_DB` 留空：多库模式（dev/sit 常用）
- 写操作默认关闭；需 `ALLOW_INSERT_OPERATION` 等 env 显式开启
- secrets 写在 `mcp.workspace.secrets.json` → `projects.<id>.profiles.<env>`

## Redis

```json
"REDIS_URL": "redis://:password@192.168.3.25:6379/1"
```

- 无 ACL：`redis://:password@host:port/db`，勿写 `root:` 前缀
- 密码原文，`>` 勿编码为 `%3E`

## Elasticsearch

- 默认未在所有 profile 模板启用；加入 `servers` 后需在 profile env 配置 `ES_URL` 与认证
- `OTEL_LOG_LEVEL=none` 已在 registry 默认

## 与 mcp-dbx 对比

| 维度 | mcp-db（本 skill） | mcp-dbx |
|------|-------------------|---------|
| workspace | profile 含 mysql/redis/es | `fixedServers` 含 `dbx` |
| 切 SIT MySQL | `switch-all-mcp-profiles.ps1 sit` | MCP `dbx` + 连接名 `broker-sit-mysql` |
| 连接配置 | workspace env + secrets | DBX 桌面端连接名 |
| Agent 工具 | `{projectId}-mysql-mcp` 等 | MCP `dbx` |

## 校验

```powershell
python .cursor/.generated/probe-all-projects-dev.py
```

确认 `dataAccess=profile-mcp` 且 `fixedServers` 不含 `dbx`。
