# MCP Switch — 详细参考

> 安装与本机二进制：见 `mcp-install/scripts/init-mcp.*`

## 架构

```
mcp-registry.json
        +
mcp-switch/mcp.workspace.json           地址、tools、项目 path（无密钥）
mcp-switch/mcp.workspace.secrets.json   密钥（加载时自动合并）
        ↓
switch-*.ps1 / mcp-configurator.py
        ↓
~/.cursor/mcp.json                     Cursor 生效（勿手改）
        ↓
.cursor/.generated/                      xxl-job-<profile>.yaml、探测脚本
```

- MCP 名固定；切换 profile **替换**分环境 server 块。
- **fixedServers**：`codegraph`、`ONES` 不变。
- 多项目：工具名 `{projectId}-<服务>`（如 `broker-mysql-mcp`）。

## workspace / secrets 字段

| 字段 | 说明 |
|------|------|
| `activeProfile` | 当前环境；switch 会更新 |
| `dataAccess` | `dbx-mcp` 或 `profile-mcp` |
| `dataLayerDbServers` | profile 模式下启用的 mysql/redis/es MCP |
| `tools` | `UVX_BIN`、`NPX_BIN`、`LOKI_MCP_BIN` 等 |
| `projects.<id>.path` | 本机代码库绝对路径 |
| `projects.<id>.profiles.<name>.servers` | 该环境启用的 MCP |
| `projects.<id>.profiles.<name>.env` | 非密钥连接参数 |

密钥（`mcp.workspace.secrets.json`）：`MYSQL_PASS`、`REDIS_URL`、`NACOS_PASSWORD`、`XXL_JOB_PASSWORD`、`XXL_JOB_ACCESS_TOKEN`、`ROCKETMQ_AK/SK`。

```powershell
# 从旧 workspace 提取密钥
python .cursor/skills/shared/mcp-switch/scripts/mcp-configurator.py `
  --project-root . --skill-root .cursor/skills/shared/mcp-switch `
  --extract-secrets --force
```

### 新增 profile

1. 编辑 `mcp.workspace.json` → `projects.<id>.profiles.uat`
2. 同步 `mcp.workspace.secrets.json` 中对应 secrets
3. `switch-all-mcp-profiles.ps1 uat` 或 `switch-mcp-profile.ps1 uat`

## 团队 dev / sit 差异

| 组件 | dev | sit |
|------|-----|-----|
| Loki | `http://192.168.3.25:3100` | 相同 |
| MySQL | `192.168.3.8:3306`，多库 | `192.168.3.237:3306`，多库 |
| Redis | db **1** | db **2**，同 host |
| Nacos | user **app**，dev namespace UUID | 同 user，sit namespace UUID |
| XXL-Job | dev 域名 | sit 域名 + accessToken |

## 连接探测

| 脚本 | 作用 |
|------|------|
| `probe-all-projects-dev.py` | 三项目后端 + MCP 工具层（推荐） |
| `verify-mcp-dev.py` | 轻量 TCP/认证 |
| `probe-rocketmq-mcp.py` | jar / SSE / NameServer |
| `probe-rocketmq-mcp-handshake.py` | MCP tools/list |
| `query-mq-via-mcp.py` | topic 积压样本 |

```powershell
python .cursor/.generated/probe-all-projects-dev.py
python .cursor/.generated/verify-mcp-dev.py
python .cursor/.generated/probe-rocketmq-mcp-handshake.py
```

### 探测预期

| 检查项 | 预期 |
|--------|------|
| Loki `/ready` | `ready` |
| MySQL | 8.0.x 认证通过 |
| Redis dbsize | dev db1 / sit db2 > 0 |
| Nacos login + service list | 有 service count |
| XXL-Job login | `code=200` |
| rocketmq jar | 6868/6869 监听 |

## switch 运行时说明

### XXL-JOB

switch 时自动生成 `.cursor/.generated/xxl-job-<profile>.yaml`；sit 的 `XXL_JOB_ACCESS_TOKEN` 写入 yaml。

### Nacos Router

- `search_mcp_server` 返回 `{}` **正常**（路由型 MCP）
- 后端验证：`/nacos/v1/auth/login` + `/nacos/v1/ns/service/list`

### Redis URL（运行时）

| 场景 | 格式 |
|------|------|
| 无 ACL | `redis://:password@host:port/db` |
| 密码含特殊字符 | 原文写入，勿错误编码 |

### RocketMQ switch 链路

`switch-*-profiles.ps1` → `restart-rocketmq-mcp.ps1` → `D:\mcp\restart-rocketmq-mcp.ps1` → **`reload-cursor-window.ps1`（默认）**

- 经纪商端口 **6868**，B2C **6869**，按端口独立启停
- Cursor 索引：`STATUS.md` 可能出现但 jar 探测为准 → Reload / Disable→Enable

## 故障排查（切换 / 运行时）

| 现象 | 处理 |
|------|------|
| Not connected | Reload Window |
| redis → 127.0.0.1 | 确认 mcp.json 有 `--url`；Reload |
| redis 认证失败 | `redis://:password@...`，勿 `root:` 前缀 |
| mysql Unknown database | `MYSQL_DB` 留空（多库） |
| xxl-job 启动失败 | registry pin `fastmcp==2.2.0` |
| nacos router 空列表 | 正常；用 naming API 验后端 |
| rocketmq 6868 未监听 | 查 `D:\mcp\logs\`；restart 脚本轮询 30s |
| rocketmq `ak不能为空` | 重建本地 patch 版 jar（见 install reference） |

## 验证清单

1. `switch-all-mcp-profiles.ps1 <profile>` — 地址输出正确
2. 自动 Reload Window（或手动 `Ctrl+Shift+P` → Reload Window；跳过自动 reload 加 `-NoReloadWindow`）
3. `probe-all-projects-dev.py` — 后端 0 失败
4. 抽样 MCP：`who_am_i` / `SELECT 1` / `dbsize` / `loki_label_names`

## page-agent 共存

合并写入 `~/.cursor/mcp.json`；非 registry 管理的条目保留。
