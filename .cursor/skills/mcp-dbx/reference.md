# DBX MCP — 连接命名参考

> 命名与 DBX 桌面端、旧版 `dbx-data-access` 约定（本仓库未捆绑） 保持一致；MCP 通过连接 **name** 访问，不使用 `dbx` CLI。

## 格式

```
{projectId}-{env}[-{variant}]-{type}
```

## 矩阵示例

| projectId | env | type | 连接名 |
|-----------|-----|------|--------|
| broker | dev | mysql | `broker-dev-mysql` |
| broker | sit | redis | `broker-sit-redis` |
| broker | pre | es | `broker-pre-es` |
| cloud | dev | mysql | `cloud-dev-mysql` |
| b2c | sit | mysql | `b2c-sit-mysql` |
| broker | dev | mysql-log | `broker-dev-mysql-log` |
| broker | dev-tmp | mysql | `broker-dev-tmp-mysql` |

## type 后缀

| 类型 | 后缀 |
|------|------|
| MySQL | `mysql` |
| MySQL 日志库 | `mysql-log` |
| Redis | `redis` |
| Elasticsearch | `es` |

## 规则

1. 全英文小写 + 连字符
2. **name 全局唯一**（一种 type 一个 name）
3. `projectId` 与 mcp-switch 一致：`broker` / `cloud` / `b2c`
4. 同环境多个同类实例加 host 后缀：`b2c-dev-redis-141`

## 与 mcp-db / mcp-switch 的关系

| 操作 | mcp-dbx 模式 | mcp-db 模式 |
|------|-------------|-------------|
| 查经纪商 SIT MySQL | MCP `dbx` → `broker-sit-mysql` | `broker-mysql-mcp`（需先 switch 到 sit） |
| 切 SIT 日志 | `switch-all-mcp-profiles.ps1 sit` | 同左 |
| 切 SIT MySQL 地址 | **不需要**（换连接名即可） | 需要 switch sit |

## 校验

在 DBX 桌面端确认连接存在；`dataAccess=dbx-mcp` 时 workspace profile 不应含 `mysql-mcp` / `redis-mcp` / `elasticsearch-mcp`。
