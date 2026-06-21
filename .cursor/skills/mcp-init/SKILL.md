---
name: mcp-init
description: >-
  Initialize and maintain Cursor MCP from mcp.config.json + mcp-registry.
  Use for MCP setup/onboarding, editing mcp.config.json, switching dev/sit/pre,
  verifying loki/mysql/redis/xxl-job/nacos/ONES/codegraph connectivity, or mcp-init.
---

# MCP 初始化（mcp-init）

从 **注册表 + 单文件配置** 生成 `~/.cursor/mcp.json`。脚本与本 skill 同目录。

## 文件一览

| 文件 | git | 作用 |
|------|-----|------|
| `.cursor/mcp.config.json` | ❌ | 唯一用户配置（密钥、`activeProfile`、各环境 env） |
| `.cursor/mcp.config.example.json` | ✅ | 模板 |
| [mcp-registry.json](mcp-registry.json) | ✅ | 服务模板（install、stdio/http 启动方式） |
| `.cursor/.generated/xxl-job-<profile>.yaml` | ❌ | switch 时由 configurator 自动生成 |
| `.cursor/.generated/probe-mcp-dev.py` | ❌ | 后端 + MCP 工具层探测脚本（可复跑） |
| `~/.cursor/mcp.json` | — | Cursor **生效**配置（脚本生成，勿手改） |

```powershell
copy .cursor\mcp.config.example.json .cursor\mcp.config.json
# 编辑 tools、fixedEnv、profiles.*.env
.cursor/skills/shared/mcp-init/scripts/switch-mcp-profile.ps1 dev
# Reload Window
```

改 `mcp.config.json` 或 registry 后：**switch → Reload Window**。

## 当前启用的 MCP（dev / sit / pre）

| MCP ID | 说明 | 仓库 |
|--------|------|------|
| `codegraph` | 代码知识图谱（固定） | https://github.com/colbymchenry/codegraph |
| `ONES` | 项目/Wiki（固定） | https://sz.ones.cn/mcp |
| `loki-mcp` | Loki 日志 | https://github.com/grafana/loki-mcp |
| `mysql-mcp` | MySQL | https://github.com/benborla/mcp-server-mysql |
| `redis-mcp` | Redis | https://github.com/redis/mcp-redis |
| `xxl-job-mcp` | XXL-JOB 调度 | https://github.com/zz-wenzb/xxl-job-mcp |
| `nacos-mcp-router` | Nacos 路由/代理 | https://github.com/nacos-group/nacos-mcp-router |

## 可选 MCP（registry 有模板，默认未启用）

| MCP ID | 说明 | 启用方式 |
|--------|------|----------|
| `elasticsearch-mcp` | Elasticsearch 官方 MCP | 加入 `profiles.*.servers`，配置 `ES_URL` + 认证，switch |
| `rocketmq-mcp` | RocketMQ 管理（SSE） | 部署 jar 后加入 `servers`，配置 `ROCKETMQ_MCP_URL`，switch |
| `feishu-cli` | 飞书（**非 MCP**） | 终端 `lark-cli` + Skills |

## 配置结构

```json
{
  "activeProfile": "dev",
  "fixedServers": ["codegraph", "ONES"],
  "profiles": {
    "dev": {
      "servers": ["loki-mcp", "mysql-mcp", "redis-mcp", "xxl-job-mcp", "nacos-mcp-router"],
      "env": { "LOKI_URL": "...", "MYSQL_HOST": "...", "REDIS_URL": "...", ... }
    }
  }
}
```

### 固定 vs 分环境

| 类型 | MCP | 切换 profile |
|------|-----|--------------|
| **固定** | `codegraph`、`ONES` | **不变** |
| **分环境** | `loki-mcp`、`mysql-mcp`、`redis-mcp`、`xxl-job-mcp`、`nacos-mcp-router` | **替换** |

### 团队环境参数（dev / sit）

| 项 | dev | sit |
|----|-----|-----|
| Loki | `http://192.168.3.25:3100` | 同左 |
| MySQL | `192.168.3.8:3306`，`MYSQL_DB=""` 多库 | `192.168.3.237:3306`，`MYSQL_DB=""` 多库（broker4* 等） |
| Redis | `redis://:password@192.168.3.25:6379/1` | 同 host，**db=2** |
| XXL-Job | `xxl-job.dev-ys-broker.com` | `xxl-job.sit-ys-broker.com`（含 `XXL_JOB_ACCESS_TOKEN`） |
| Nacos | `192.168.3.25:8848`，user **app**，dev namespace UUID | 同 host/user，**sit namespace UUID** |

> **Redis 易错**：无 ACL 时用 `redis://:password@host:port/db`，**不要**写 `redis://root:password@...`。

## 切换环境（Agent 必做）

```powershell
.cursor/skills/shared/mcp-init/scripts/switch-mcp-profile.ps1 dev
.cursor/skills/shared/mcp-init/scripts/switch-mcp-profile.ps1 sit
.cursor/skills/shared/mcp-init/scripts/switch-mcp-profile.ps1 pre
```

切换后**必须**：展示脚本「MCP 配置地址」输出，并提示 **Reload Window**。

## 各服务 env 要点

| 服务 | 关键配置 | 注意 |
|------|----------|------|
| loki-mcp | `LOKI_MCP_BIN` + `LOKI_URL` | stdio；验证 `/ready` |
| mysql-mcp | `MYSQL_*` | `MYSQL_DB` 留空 = 多库（dev/sit 均如此） |
| redis-mcp | `REDIS_URL` | `redis://:password@host:6379/db`；密码原文，勿 `%3E` |
| xxl-job-mcp | `XXL_JOB_*` | switch 生成 yaml；registry pin `fastmcp==2.2.0` |
| nacos-mcp-router | `NACOS_*` | namespace 填 UUID；路由型 MCP |
| ONES | `fixedEnv.ONES_MCP_URL` | Cursor OAuth |
| codegraph | fixedServers | 需 `codegraph init` 后才有工具 |

## 启用可选 MCP

在 `mcp.config.json` 对应 profile 的 `servers` 数组追加 ID，补齐 env 后 switch：

```json
"servers": [..., "elasticsearch-mcp"],
"env": {
  "ES_URL": "http://192.168.3.25:9200",
  "ES_API_KEY": "..."
}
```

```json
"servers": [..., "rocketmq-mcp"],
"env": {
  "ROCKETMQ_MCP_URL": "http://rocketmq-check.dev-ys-broker.com:6868/sse"
}
```

## MCP 服务安装

详见 [reference.md](reference.md)；常用：

- **loki**：`LOKI_MCP_BIN` + `LOKI_URL`
- **mysql**：Node 20+，`NPX_BIN`
- **redis**：`uvx --from redis-mcp-server redis-mcp-server --url "redis://:password@host:6379/db"`
- **xxl-job**：`uvx --with fastmcp==2.2.0 --from git+https://github.com/zz-wenzb/xxl-job-mcp xxl-job-mcp --config <yaml>`
- **nacos**：`uvx nacos-mcp-router@latest`（首次启动可能较慢）

## 连接探测（Agent）

用户要求验证/探测连通性时，按顺序执行：

### 1. 后端 API 层

```powershell
# 当前 activeProfile（或指定 profile）
D:\miniconda3\python.exe .cursor\.generated\probe-mcp-dev.py
D:\miniconda3\python.exe .cursor\.generated\probe-mcp-dev.py sit
```

或轻量版（仅网络/认证）：

```powershell
D:\miniconda3\python.exe .cursor\.generated\verify-mcp-dev.py
```

`probe-mcp-dev.py` 会探测 Loki / MySQL / Redis / Nacos naming / XXL-Job login / ONES，并统计 Cursor `mcps/` 目录下各 server 工具数。

### 2. MCP 工具层（Reload 后）

| MCP | 抽样工具 | 预期 |
|-----|----------|------|
| ONES | `who_am_i` | 返回当前用户 |
| loki-mcp | `loki_label_names` | 返回 label 列表 |
| mysql-mcp | `mysql_query` → `SELECT 1` | 返回 ok |
| redis-mcp | `dbsize` / `info` | db1 有 key 数 |
| xxl-job-mcp | `get_dashboard` / `list_executors` | 13 工具在线 |
| nacos-mcp-router | 进程 Connected | 3 工具；`search_mcp_server` 空列表属正常 |
| codegraph | — | 未 `codegraph init` 时 0 工具 |

### 3. 探测结论汇报格式

向用户汇报时区分两层：

- **后端**：TCP/HTTP/认证是否通过
- **MCP 进程**：Settings → MCP 是否 Connected；工具能否调用

## nacos-mcp-router 说明

- **路由型 MCP**，不是直连 Nacos 的 CRUD 客户端
- `search_mcp_server` 返回 `{}` 表示尚未通过 router 挂载子 MCP，**不代表 Nacos 连不上**
- 验证 Nacos 连通：后端 login + naming API（见 reference.md）

## 相关规则

- Agent 切换/展示：`.cursor/rules/memory/mcp-environment.mdc`
- 故障排查：[reference.md](reference.md)
