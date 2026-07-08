---
name: mcp-install
description: >-
  Install and configure Cursor MCP from mcp.config.json + mcp-registry.
  Use for MCP onboarding, first-time setup, editing mcp.config.json,
  installing loki/mysql/redis/xxl-job/nacos/rocketmq/ONES/codegraph,
  enabling optional MCPs, or init-mcp.
---

# MCP 安装（mcp-install）

从 **注册表 + 单文件配置** 生成 `~/.cursor/mcp.json`。脚本与本 skill 同目录。

> 日常切换 dev/sit/pre 请用 **[mcp-switch](../mcp-switch/SKILL.md)**，不要在本 skill 里重复执行 switch。

## 文件一览

| 文件 | git | 作用 |
|------|-----|------|
| `.cursor/mcp.config.json` | ❌ | 唯一用户配置（密钥、`activeProfile`、各环境 env） |
| `.cursor/mcp.config.example.json` | ✅ | 模板 |
| [mcp-registry.json](mcp-registry.json) | ✅ | 服务模板（install、stdio/http 启动方式） |
| [mcp-switch/mcp.projects.example.json](../mcp-switch/mcp.projects.example.json) | ✅ | 多项目注册表模板 |
| `.cursor/.generated/xxl-job-<profile>.yaml` | ❌ | switch 时由 configurator 自动生成 |
| `scripts/init-mcp.ps1` | ✅ | 生成/合并 MCP 配置 |
| `~/.cursor/mcp.json` | — | Cursor **生效**配置（脚本生成，勿手改） |

> 切换脚本见 **[mcp-switch/scripts/](../mcp-switch/SKILL.md)**；`mcp-install/scripts/switch-*.ps1` 为兼容转发。

## 首次配置

```powershell
copy .cursor\mcp.config.example.json .cursor\mcp.config.json
# 多项目时设置 projectId / projectLabel
# 多项目注册表（用户目录，勿提交 git）：
copy .cursor\skills\shared\mcp-switch\mcp.projects.example.json $env:USERPROFILE\.cursor\mcp.projects.json
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev
```

改 `mcp.config.json` 或 registry 后：**init 或 switch → Reload Window**。

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
| `rocketmq-mcp` | RocketMQ 管理（HTTP SSE） | https://github.com/francisoliverlee/rocketmq-mcp |

## 可选 MCP（registry 有模板，默认未启用）

| MCP ID | 说明 | 启用方式 |
|--------|------|----------|
| `elasticsearch-mcp` | Elasticsearch 官方 MCP | 加入 `profiles.*.servers`，配置 `ES_URL` + 认证，再 switch |
| `feishu-cli` | 飞书（**非 MCP**） | 终端 `lark-cli` + Skills |

## 配置结构

```json
{
  "activeProfile": "dev",
  "fixedServers": ["codegraph", "ONES"],
  "profiles": {
    "dev": {
      "servers": ["loki-mcp", "mysql-mcp", "redis-mcp", "xxl-job-mcp", "nacos-mcp-router", "rocketmq-mcp"],
      "env": {
        "LOKI_URL": "...",
        "MYSQL_HOST": "...",
        "REDIS_URL": "...",
        "ROCKETMQ_MCP_URL": "http://127.0.0.1:6868/sse",
        "ROCKETMQ_NS_ADDR": "192.168.3.25:9876"
      }
    }
  }
}
```

### 固定 vs 分环境

| 类型 | MCP | 切换 profile |
|------|-----|--------------|
| **固定** | `codegraph`、`ONES` | **不变** |
| **分环境** | `loki-mcp`、`mysql-mcp`、`redis-mcp`、`xxl-job-mcp`、`nacos-mcp-router`、`rocketmq-mcp` | **替换**（见 mcp-switch） |

## 各服务 env 要点

| 服务 | 关键配置 | 注意 |
|------|----------|------|
| loki-mcp | `LOKI_MCP_BIN` + `LOKI_URL` | stdio；验证 `/ready` |
| mysql-mcp | `MYSQL_*` | `MYSQL_DB` 留空 = 多库（dev/sit 均如此） |
| redis-mcp | `REDIS_URL` | `redis://:password@host:6379/db`；密码原文，勿 `%3E` |
| xxl-job-mcp | `XXL_JOB_*` | switch 生成 yaml；registry pin `fastmcp==2.2.0` |
| nacos-mcp-router | `NACOS_*` | namespace 填 UUID；路由型 MCP |
| rocketmq-mcp | `ROCKETMQ_MCP_URL` + `ROCKETMQ_NS_ADDR` | jar 本地进程；**AK/SK 可选** |
| ONES | `fixedEnv.ONES_MCP_URL` | Cursor OAuth |
| codegraph | fixedServers | 需 `codegraph init` 后才有工具 |

> **Redis 易错**：无 ACL 时用 `redis://:password@host:port/db`，**不要**写 `redis://root:password@...`。

## 启用 / 禁用可选 MCP

在 `mcp.config.json` 对应 profile 的 `servers` 数组追加或移除 ID，补齐 env 后执行 switch（见 mcp-switch）：

```json
"servers": [..., "elasticsearch-mcp"],
"env": {
  "ES_URL": "http://192.168.3.25:9200",
  "ES_API_KEY": "..."
}
```

禁用 rocketmq：从 `servers` 移除 `rocketmq-mcp` 后 switch（会自动 stop 本地 jar）。

## MCP 服务安装

详见 [reference.md](reference.md)；常用：

- **loki**：`LOKI_MCP_BIN` + `LOKI_URL`
- **mysql**：Node 20+，`NPX_BIN`
- **redis**：`uvx --from redis-mcp-server redis-mcp-server --url "redis://:password@host:6379/db"`
- **xxl-job**：`uvx --with fastmcp==2.2.0 --from git+https://github.com/zz-wenzb/xxl-job-mcp xxl-job-mcp --config <yaml>`
- **nacos**：`uvx nacos-mcp-router@latest`（首次启动可能较慢）
- **rocketmq**：本地 `D:\mcp\rocketmq-mcp\build.ps1`（Java 17）→ jar 监听 6868

构建与部署 rocketmq jar 见 [reference.md — RocketMQ MCP](reference.md#rocketmq-mcp) 与 `D:\mcp\README.md`。

## init 命令

```powershell
.cursor/skills/shared/mcp-install/scripts/init-mcp.ps1 -ListProfiles
.cursor/skills/shared/mcp-install/scripts/init-mcp.ps1 -Profile dev
```

配置就绪后，用 **mcp-switch** 切换环境并验证连通性。

## 相关

- 环境切换：[mcp-switch](../mcp-switch/SKILL.md)
- Agent 规则：`.cursor/rules/memory/mcp-environment.mdc`
- 故障排查：[reference.md](reference.md)
