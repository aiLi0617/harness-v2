---
name: mcp-switch
description: >-
  Switch Cursor MCP environment profile between dev, sit, and pre.
  Use when the user asks to enable dev/sit/pre, switch MCP environment,
  switch all projects MCP (broker/cloud/b2c), show project MCP mapping,
  verify MCP connectivity after switch, or mcp-switch.
---

# MCP 环境切换（mcp-switch）

在 **已安装/已配置** MCP 的前提下，切换环境 profile，重新生成 `~/.cursor/mcp.json`。

> 首次安装、编辑 registry、安装各 MCP 二进制：见 **[mcp-install](../mcp-install/SKILL.md)**。

## 文件一览

| 文件 | git | 作用 |
|------|-----|------|
| **`~/.cursor/mcp.workspace.json`** | ❌ | 环境地址、tools 路径、项目 path（**不含密钥**） |
| **`~/.cursor/mcp.workspace.secrets.json`** | ❌ | 密钥（密码、REDIS_URL、Token 等） |
| [mcp.workspace.example.json](mcp.workspace.example.json) | ✅ | workspace 模板（无真实密钥） |
| [mcp.workspace.secrets.example.json](mcp.workspace.secrets.example.json) | ✅ | secrets 模板（`change-me` 占位） |
| [mcp-registry.json](mcp-registry.json) | ✅ | 服务模板（唯一副本） |
| `scripts/switch-all-mcp-profiles.ps1` | ✅ | 多项目统一切换 |
| `scripts/switch-mcp-profile.ps1` | ✅ | 单项目切换 |
| `scripts/show-project-mcp.ps1` | ✅ | 查看当前项目 MCP 映射 |
| `scripts/mcp-configurator.py` | ✅ | 核心配置生成 |
| `scripts/restart-rocketmq-mcp.ps1` | ✅ | switch 后重启 rocketmq jar |
| `scripts/reload-cursor-window.ps1` | ✅ | switch 后自动 Reload Window |
| `~/.cursor/mcp.json` | — | Cursor **生效**配置（脚本生成，勿手改） |

> 所有脚本统一读取 `~/.cursor/mcp.workspace.json`；旧版 per-project `mcp.config.json` 仅用于 `--migrate-to-workspace` 迁移。

## 单文件配置（推荐）

### 1. 首次迁移（从三份 per-project 配置合并）

```powershell
copy .cursor\skills\shared\mcp-switch\mcp.workspace.example.json $env:USERPROFILE\.cursor\mcp.workspace.json
# 编辑后切换；或从现有 per-project 配置自动合并：
python .cursor/skills/shared/mcp-switch/scripts/mcp-configurator.py `
  --project-root . --skill-root .cursor/skills/shared/mcp-switch `
  --migrate-to-workspace --force
```

### 2. 结构

```json
{
  "activeProfile": "dev",
  "tools": { "UVX_BIN": "...", "LOKI_MCP_BIN": "..." },
  "fixedServers": ["codegraph", "ONES"],
  "projects": {
    "broker": { "label": "经纪商", "path": "D:/project/zfnjjs-two", "profiles": { "dev": {...}, "sit": {...} } },
    "cloud":  { ... },
    "b2c":    { ... }
  }
}
```

**改配置只编辑这一份**：`C:\Users\<你>\.cursor\mcp.workspace.json`

### 3. 统一切换

```powershell
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev
```

## 两种模式

| 模式 | 适用 | 切换命令 | Cursor 中工具名 |
|------|------|----------|-----------------|
| **单项目** | 只维护一个代码库 | `switch-mcp-profile.ps1` | `mysql-mcp`、`loki-mcp`（无前缀） |
| **多项目** | 经纪商 / 云商 / B2C 等并行 | `switch-all-mcp-profiles.ps1` | `{projectId}-mysql-mcp`（带前缀） |

## 多项目：一次切换全部环境（legacy 分文件模式）

> 若已使用 `mcp.workspace.json`，跳过本节。

### 1. 各项目声明身份

每个项目根目录 `.cursor/mcp.config.json` 增加 `projectId`（旧模式）。

```json
{
  "projectId": "broker",
  "projectLabel": "经纪商",
  ...
}
```

| projectId | 建议 |
|-----------|------|
| `broker` | 经纪商 |
| `cloud` | 云商 |
| `b2c` | B2C |

### 2. 全局项目注册表

复制模板到用户目录（**勿提交 git**，路径因机器而异）：

```powershell
copy .cursor\skills\shared\mcp-switch\mcp.projects.example.json $env:USERPROFILE\.cursor\mcp.projects.json
# 编辑三个项目的绝对路径
```

### 3. 统一切换

```powershell
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 sit
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 pre
```

效果：

- 三个项目的 `activeProfile` **同时**更新为 sit
- `~/.cursor/mcp.json` 合并写入三套 MCP（用 `projectId` 前缀区分）
- `ONES`、`codegraph` 为共享服务，**不加前缀**

### 4. 在当前项目找到对应 MCP（Agent 必做）

**识别步骤：**

1. 读 `~/.cursor/mcp.workspace.json` 中当前工作区 path 对应的 `projectId`（如 `broker`）
2. 多项目模式下，分环境工具名 = **`{projectId}-<服务>`**
3. 共享工具直接用原名：`ONES`、`codegraph`

**示例（经纪商 + sit）：**

| 逻辑服务 | Cursor MCP 名 |
|----------|---------------|
| MySQL | `broker-mysql-mcp` |
| Redis | `broker-redis-mcp` |
| Loki | `broker-loki-mcp` |
| ONES | `ONES` |
| 代码图谱 | `codegraph` |

**查看完整映射：**

```powershell
.cursor/skills/shared/mcp-switch/scripts/show-project-mcp.ps1
```

输出含 `projectId`、当前 `activeProfile`、每个逻辑服务对应的 Cursor 工具名，以及是否在 `mcp.json` 中已注册（✓/✗）。

> **原理**：Cursor 全局只有一份 `~/.cursor/mcp.json`。多项目并存时必须用前缀区分，否则三套 `mysql-mcp` 会互相覆盖。

> **rocketmq 多项目端口**：经纪商 `6868`，B2C `6869`（`ROCKETMQ_MCP_URL` 中配置）；restart 脚本按端口独立启停，互不干扰。

## 单项目切换命令（Agent 必做）

```powershell
.cursor/skills/shared/mcp-switch/scripts/switch-mcp-profile.ps1 dev
.cursor/skills/shared/mcp-switch/scripts/switch-mcp-profile.ps1 sit
.cursor/skills/shared/mcp-switch/scripts/switch-mcp-profile.ps1 pre
```

| 用户说法 | 命令 |
|----------|------|
| 启用 dev / 本地 | `switch-mcp-profile.ps1 dev` |
| 启用 sit / SIT | `switch-mcp-profile.ps1 sit` |
| 启用 pre / 预发 | `switch-mcp-profile.ps1 pre` |

切换后**必须**：

1. 向用户**原文展示**脚本输出的「MCP 配置地址」区块
2. 脚本**默认自动 Reload Window**（`reload-cursor-window.ps1` → `cursor --open-url command:workbench.action.reloadWindow`）；若需跳过加 `-NoReloadWindow`
3. 若 profile 含 `rocketmq-mcp`，脚本会自动 **restart 本地 jar**（`-DNS_ADDR=...`）

## 固定 vs 分环境

| 类型 | MCP | 切换 profile |
|------|-----|--------------|
| **固定** | `codegraph`、`ONES` | **不变** |
| **分环境** | `loki-mcp`、`mysql-mcp`、`redis-mcp`、`xxl-job-mcp`、`nacos-mcp-router`、`rocketmq-mcp` | **替换** |

当前环境以 `mcp.workspace.json` 的 `activeProfile` 为准。

## 团队环境参数（dev / sit）

| 项 | dev | sit |
|----|-----|-----|
| Loki | `http://192.168.3.25:3100` | 同左 |
| MySQL | `192.168.3.8:3306`，`MYSQL_DB=""` 多库 | `192.168.3.237:3306`，`MYSQL_DB=""` 多库 |
| Redis | `redis://:password@192.168.3.25:6379/1` | 同 host，**db=2** |
| XXL-Job | `xxl-job.dev-ys-broker.com` | `xxl-job.sit-ys-broker.com`（含 `XXL_JOB_ACCESS_TOKEN`） |
| Nacos | `192.168.3.25:8848`，user **app**，dev namespace UUID | 同 host/user，**sit namespace UUID** |
| RocketMQ | NameServer `192.168.3.25:9876`，jar 本地 `:6868/sse` | 同 NS（按环境可改 `ROCKETMQ_NS_ADDR`） |

## 连接探测（Agent）

用户要求验证/探测连通性时，**先确认已 switch + Reload**，再按顺序执行：

### 1. 后端 API 层

```powershell
python .cursor/.generated/probe-all-projects-dev.py
```

轻量版（仅网络/认证）：

```powershell
D:\miniconda3\python.exe .cursor\.generated\verify-mcp-dev.py
```

### 1b. rocketmq-mcp 专项（profile 含 rocketmq 时）

```powershell
D:\miniconda3\python.exe .cursor\.generated\probe-rocketmq-mcp.py
D:\miniconda3\python.exe .cursor\.generated\probe-rocketmq-mcp-handshake.py
D:\miniconda3\python.exe .cursor\.generated\query-mq-via-mcp.py
```

### 2. MCP 工具层（Reload 后）

| MCP | 抽样工具 | 预期 |
|-----|----------|------|
| ONES | `who_am_i` | 返回当前用户 |
| loki-mcp | `loki_label_names` | 返回 label 列表 |
| mysql-mcp | `mysql_query` → `SELECT 1` | 返回 ok |
| redis-mcp | `dbsize` / `info` | db1/db2 有 key 数 |
| xxl-job-mcp | `get_dashboard` / `list_executors` | 13 工具在线 |
| nacos-mcp-router | 进程 Connected | 3 工具 |
| rocketmq-mcp | handshake / `query-mq-via-mcp.py` | jar 在线即可 |
| codegraph | — | 未 `codegraph init` 时 0 工具 |

### 3. 汇报格式

向用户汇报时区分两层：

- **后端**：TCP/HTTP/认证是否通过（含 rocketmq jar + NameServer）
- **MCP 进程**：Settings → MCP 是否 Connected；工具能否调用

## nacos-mcp-router 说明

- **路由型 MCP**，不是直连 Nacos 的 CRUD 客户端
- `search_mcp_server` 返回 `{}` 表示尚未挂载子 MCP，**不代表 Nacos 连不上**

## Agent 工具名

| 任务 | 方式 |
|------|------|
| 查日志 | MCP `loki-mcp` |
| 查 MySQL | MCP `mysql-mcp` |
| 查 Redis | MCP `redis-mcp` |
| XXL-JOB 任务 | MCP `xxl-job-mcp` |
| Nacos 配置/服务 | MCP `nacos-mcp-router` |
| ONES / Wiki | MCP `ONES`（固定） |
| 代码图谱 | MCP `codegraph`（固定） |
| 飞书 | **终端 `lark-cli`**（非 MCP） |

## 相关

- 安装与初始化：[mcp-install](../mcp-install/SKILL.md)
- 切换/探测参考：[reference.md](reference.md)
- 安装参考：[mcp-install/reference.md](../mcp-install/reference.md)
- Agent 规则：`.cursor/rules/memory/mcp-environment.mdc`
