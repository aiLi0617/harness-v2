---
name: mcp-install
description: >-
  Install and bootstrap Cursor MCP for new team members.
  Use for MCP onboarding, first-time setup, installing loki/mysql/redis/xxl-job/nacos/rocketmq/ONES/codegraph,
  creating mcp.workspace.json, prerequisite checks, bootstrap-mcp, or init-mcp.
---

# MCP 安装（mcp-install）

**职责边界：**

| Skill | 做什么 | 不做什么 |
|-------|--------|----------|
| **mcp-install**（本 skill） | 本机依赖检查、生成 workspace、安装二进制/jar、首次 init | 日常 dev/sit/pre 切换 |
| **mcp-switch** | 读取 workspace → 生成 `~/.cursor/mcp.json`、重启 rocketmq jar | 安装二进制 |

> 日常切换环境：**[mcp-switch](../mcp-switch/SKILL.md)**

## 文件一览

| 文件 | git | 作用 |
|------|-----|------|
| **`~/.cursor/mcp.workspace.json`** | ❌ | 环境地址、tools 路径、项目 path（**不含密钥**） |
| **`~/.cursor/mcp.workspace.secrets.json`** | ❌ | 密钥（密码、REDIS_URL、Token 等） |
| [mcp-switch/mcp.workspace.example.json](../mcp-switch/mcp.workspace.example.json) | ✅ | workspace 模板（无密钥） |
| [mcp-switch/mcp.workspace.secrets.example.json](../mcp-switch/mcp.workspace.secrets.example.json) | ✅ | secrets 模板（`change-me` 占位） |
| [mcp-switch/mcp-registry.json](../mcp-switch/mcp-registry.json) | ✅ | MCP 服务启动模板（唯一副本） |
| `scripts/bootstrap-mcp.ps1` | ✅ | **新成员入口**：依赖检查 + 生成 workspace/secrets |
| `scripts/init-mcp.ps1` | ✅ | 单项目 init（需已有 workspace） |
| `scripts/init-mcp.sh` | ✅ | init-mcp.ps1 的 Unix 版 |
| `~/.cursor/mcp.json` | — | Cursor **生效**配置（mcp-switch 生成，勿手改） |

## 新成员 Onboarding（推荐）

### 1. 安装本机依赖

| 依赖 | 用途 | 安装方式 |
|------|------|----------|
| Python 3 | configurator、探测脚本 | miniconda / 官方安装包 |
| Node.js 20+ | mysql-mcp（npx） | 官方 / nvm |
| uv / uvx | redis、xxl-job、nacos MCP | `pip install uv` 或 miniconda |
| Java 17+ | rocketmq-mcp jar | JDK 17 |
| loki-mcp 二进制 | Loki 日志 MCP | 见 [reference.md — Loki](reference.md) |
| codegraph（可选） | 代码图谱 | `npm i -g codegraph` + 项目内 `codegraph init` |
| pymysql、redis（可选） | 连通性探测 | `pip install pymysql redis` |

### 2. 一键引导

在**任意已 clone 的项目**（如经纪商）根目录执行：

```powershell
# 仅生成 workspace（默认 broker 路径 = 当前项目）
.cursor/skills/shared/mcp-install/scripts/bootstrap-mcp.ps1

# 三项目路径一并写入
.cursor/skills/shared/mcp-install/scripts/bootstrap-mcp.ps1 `
  -BrokerRoot D:\project\zfnjjs-two `
  -CloudRoot D:\project\yunshang-project `
  -B2cRoot D:\project\BToC

# 填好密钥后，引导 + 首次 switch
.cursor/skills/shared/mcp-install/scripts/bootstrap-mcp.ps1 -SwitchDev
```

### 3. 填写 workspace

编辑两个文件（均在 `~/.cursor/`，**勿提交 git**）：

1. **`mcp.workspace.json`** — 确认 `tools` 路径、`projects.*.path`
2. **`mcp.workspace.secrets.json`** — 将 `change-me` 替换为团队密钥

团队环境地址（Loki/MySQL host 等）已在 workspace 模板中预填；新成员通常**只需填 secrets + 本机路径**。

### 4. 切换环境（交给 mcp-switch）

```powershell
.cursor/skills/shared/mcp-switch/scripts/switch-all-mcp-profiles.ps1 dev
```

`Ctrl+Shift+P` → **Reload Window**

### 5. 验证连通性

```powershell
python .cursor/.generated/probe-all-projects-dev.py
```

## 当前启用的 MCP

| MCP ID | 说明 | 安装方式 |
|--------|------|----------|
| `codegraph` | 代码知识图谱（固定） | npm 全局 + `codegraph init` |
| `ONES` | 项目/Wiki（固定） | Cursor OAuth，无需本地安装 |
| `loki-mcp` | Loki 日志 | 本地二进制 + `LOKI_URL` |
| `mysql-mcp` | MySQL | npx 自动拉包 |
| `redis-mcp` | Redis | uvx 自动拉包 |
| `xxl-job-mcp` | XXL-JOB | uvx from GitHub |
| `nacos-mcp-router` | Nacos 路由 | uvx 自动拉包 |
| `rocketmq-mcp` | RocketMQ（HTTP SSE） | **本地 jar** + switch 时 restart |

## workspace 结构（摘要）

```json
{
  "activeProfile": "dev",
  "tools": { "UVX_BIN": "...", "NPX_BIN": "...", "LOKI_MCP_BIN": "..." },
  "fixedServers": ["codegraph", "ONES"],
  "projects": {
    "broker": { "path": "D:/project/zfnjjs-two", "profiles": { "dev": {...}, "sit": {...} } },
    "cloud":  { ... },
    "b2c":    { ... }
  }
}
```

## 启用 / 禁用 MCP

编辑 workspace / secrets 中对应 project 的 `profiles.<env>.servers` 与 env，再执行 **mcp-switch**（见 [mcp-switch/SKILL.md](../mcp-switch/SKILL.md)）。

## init 命令（已有 workspace 时，高级）

```powershell
.cursor/skills/shared/mcp-install/scripts/init-mcp.ps1 -ListProfiles
.cursor/skills/shared/mcp-install/scripts/init-mcp.ps1 -Profile dev
```

> 日常切换请直接用 `mcp-switch/scripts/switch-all-mcp-profiles.ps1`，不要用 init。

## 相关

- 环境切换：[mcp-switch](../mcp-switch/SKILL.md)
- 安装细节：[reference.md](reference.md)
- 切换/探测细节：[mcp-switch/reference.md](../mcp-switch/reference.md)
- Agent 规则：`.cursor/rules/memory/mcp-environment.mdc`
