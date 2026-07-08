# MCP Install — 详细参考

> 环境切换、探测、运行时故障排查：见 [mcp-switch/reference.md](../mcp-switch/reference.md)

## 职责

本 reference 仅覆盖 **本机依赖安装** 与 **首次配置**；不含 switch 命令与日常探测。

## 架构（安装阶段）

```
mcp-switch/mcp.workspace.example.json      地址模板（git）
mcp-switch/mcp.workspace.secrets.example.json   密钥模板（git）
        ↓ bootstrap-mcp.ps1
~/.cursor/mcp.workspace.json               本机 workspace
~/.cursor/mcp.workspace.secrets.json       本机密钥
        ↓ 见 mcp-switch
~/.cursor/mcp.json
```

## 本机依赖

| 依赖 | 用途 | 安装 |
|------|------|------|
| Python 3 | configurator、探测 | miniconda |
| Node.js 20+ | mysql-mcp | 官方 / nvm |
| uv / uvx | redis、xxl-job、nacos | `pip install uv` |
| Java 17+ | rocketmq jar 构建/运行 | JDK 17 |
| pymysql、redis | 探测脚本（可选） | `pip install pymysql redis` |

```powershell
.cursor/skills/shared/mcp-install/scripts/bootstrap-mcp.ps1
```

## 各 MCP 安装

| ID | 安装方式 |
|----|----------|
| mysql-mcp | npx 首次 switch 时自动拉包；需 Node 20+ |
| redis-mcp | uvx 自动拉包 |
| xxl-job-mcp | `uvx --with fastmcp==2.2.0 --from git+https://github.com/zz-wenzb/xxl-job-mcp` |
| nacos-mcp-router | `uvx nacos-mcp-router@latest` |
| loki-mcp | 本地二进制，配置 `tools.LOKI_MCP_BIN` |
| codegraph | `npm i -g codegraph` + 项目内 `codegraph init` |
| ONES | Cursor OAuth，无需 CLI |
| rocketmq-mcp | 本地 jar（见下） |

### Loki

```json
"tools": { "LOKI_MCP_BIN": "C:\\...\\loki-mcp.exe" }
```

验证：`curl http://<host>:3100/ready` → `ready`

### MySQL

- `MYSQL_DB` 留空 = 多库模式
- 写操作默认关闭

### XXL-JOB

- **必须 pin `fastmcp==2.2.0`**（新版 fastmcp 与 xxl-job-mcp 不兼容）
- 密码写在 `mcp.workspace.secrets.json`

### Redis

secrets 中配置完整 URL：

```json
"REDIS_URL": "redis://:password@192.168.3.25:6379/1"
```

规则：无 ACL 用 `redis://:password@...`；密码原文，勿 `%3E` 编码。

### RocketMQ MCP（本地 jar）

目录：**`D:\mcp/`**

```powershell
# Java 17+
D:\mcp\rocketmq-mcp\build.ps1
```

产物：`D:\mcp\deploy\rocketmq-mcp-server.jar`

**无 ACL 必做补丁**：`AdminUtil.validateRequiredParameters` 改为仅校验 NameServer，否则 `ak不能为空`。

手动启动：

```powershell
D:\mcp\restart-rocketmq-mcp.ps1 -NsAddr 192.168.3.25:9876 -Profile dev
```

workspace 中配置：

| 变量 | 说明 |
|------|------|
| `ROCKETMQ_MCP_URL` | `http://127.0.0.1:6868/sse`（B2C 用 6869） |
| `ROCKETMQ_NS_ADDR` | NameServer 地址 |

### codegraph

- 固定 MCP；工作区无 `.codegraph/` 时 0 工具
- 启用：`codegraph init`

### Elasticsearch（可选）

加入 `servers` + secrets/env 中 `ES_URL`；`npx -y @elastic/mcp-server-elasticsearch`

### 飞书

**禁止** `feishu-mcp`；用 `lark-cli` + Skills。

## 首次配置 checklist

1. `bootstrap-mcp.ps1` 生成 workspace + secrets 模板
2. 填写 `~/.cursor/mcp.workspace.secrets.json`（向团队索取密钥）
3. 确认 `tools` 路径、`projects.*.path`
4. 安装 loki 二进制、构建 rocketmq jar（若需要 MQ MCP）
5. 交给 **mcp-switch**：`switch-all-mcp-profiles.ps1 dev` → Reload → `probe-all-projects-dev.py`

## 安装期故障排查

| 现象 | 处理 |
|------|------|
| uvx/npx 找不到 | bootstrap 检测；`tools` 写绝对路径 |
| loki Connection closed | 确认 `LOKI_MCP_BIN` 存在 |
| rocketmq build 失败 | 确认 Java 17；`D:\jdk\jdk17` |
| xxl-job TypeError description | pin `fastmcp==2.2.0` |

## 相关

- 切换与探测：[mcp-switch/reference.md](../mcp-switch/reference.md)
- Agent 规则：`.cursor/rules/memory/mcp-environment.mdc`
