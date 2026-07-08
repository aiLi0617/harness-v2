# MCP Install — 详细参考

## 架构

```
mcp-registry.json          服务模板（install、启动 args/env）
        +
.cursor/mcp.config.json    地址、密钥、activeProfile、tools 绝对路径
        ↓
switch-mcp-profile.ps1 / mcp-configurator.py（位于 mcp-switch/scripts/）
        ↓
~/.cursor/mcp.json         Cursor 生效（勿手改）
        ↓
.cursor/.generated/        xxl-job-<profile>.yaml、探测脚本等
```

- **方式 A**：MCP 名固定；切换 profile **替换**分环境 server 块（非并联）。
- **fixedServers**：`codegraph`、`ONES` 始终保留。
- configurator 用 registry 全量 ID 清理 `~/.cursor/mcp.json` 中已禁用的 MCP（如 ES、RocketMQ）。
- 已废弃：`mcp.profiles.json`、`mcp.env.local`、`mcp.pool.json` 等。

## mcp.config.json 字段

| 字段 | 说明 |
|------|------|
| `activeProfile` | 当前环境；switch 会更新 |
| `defaultProfile` | 未指定时的默认 |
| `fixedServers` | 不随 profile 变的 MCP |
| `fixedEnv` | 如 `ONES_MCP_URL` |
| `tools` | `UVX_BIN`、`NPX_BIN`、`LOKI_MCP_BIN`（Windows 建议绝对路径） |
| `profiles.<name>.servers` | 该环境启用的分环境 MCP |
| `profiles.<name>.env` | 连接参数与密钥 |

### 新增 profile（如 uat）

1. `mcp.config.json` → `profiles.uat`
2. 同步 `mcp.config.example.json`（占位符）
3. `mcp-switch/scripts/switch-mcp-profile.ps1 uat`

## 服务对照

| ID | 传输 | 仓库 / 地址 | 配置来源 | 典型工具数 |
|----|------|-------------|----------|------------|
| codegraph | stdio | https://github.com/colbymchenry/codegraph | fixedServers | 0（未 init） |
| loki-mcp | stdio | https://github.com/grafana/loki-mcp | tools + profile `LOKI_URL` | 3 |
| mysql-mcp | stdio | https://github.com/benborla/mcp-server-mysql | profile `MYSQL_*` | 1 |
| redis-mcp | stdio | https://github.com/redis/mcp-redis | profile **`REDIS_URL`** | 47 |
| xxl-job-mcp | stdio | https://github.com/zz-wenzb/xxl-job-mcp | profile `XXL_JOB_*` → 生成 yaml | 13 |
| nacos-mcp-router | stdio | https://github.com/nacos-group/nacos-mcp-router | profile `NACOS_*` | 3 |
| rocketmq-mcp | HTTP SSE | https://github.com/francisoliverlee/rocketmq-mcp | profile `ROCKETMQ_*` + 本地 jar | 114（jar 侧） |
| ONES | HTTP | https://sz.ones.cn/mcp | fixedEnv | 68 |
| feishu-cli | — | https://github.com/larksuite/cli | 非 MCP | — |

### 可选（默认未启用）

| ID | 传输 | 仓库 | 启用 |
|----|------|------|------|
| elasticsearch-mcp | stdio | https://github.com/elastic/mcp-server-elasticsearch | 加入 `servers` + `ES_URL` 等 |

> dev/sit/pre 已默认启用 `rocketmq-mcp`；`elasticsearch-mcp` 仍默认关闭。

## 团队 dev / sit 差异

| 组件 | dev | sit |
|------|-----|-----|
| Loki URL | `http://192.168.3.25:3100` | 相同 |
| MySQL | `192.168.3.8:3306`，`MYSQL_DB=""` 多库 | `192.168.3.237:3306`，`MYSQL_DB=""` 多库 |
| Redis | db **1**，`redis://:password@192.168.3.25:6379/1` | db **2**，同 host |
| Nacos | `192.168.3.25:8848` user **app**，dev namespace UUID | 同 host/user，sit namespace UUID |
| XXL-JOB | `http://xxl-job.dev-ys-broker.com/xxl-job-admin` | `http://xxl-job.sit-ys-broker.com/xxl-job-admin` + accessToken |

## 连接探测脚本

| 脚本 | 路径 | 作用 |
|------|------|------|
| `probe-mcp-dev.py` | `.cursor/.generated/probe-mcp-dev.py` | 后端 API + Cursor mcps 工具层统计 |
| `probe-rocketmq-mcp.py` | `.cursor/.generated/probe-rocketmq-mcp.py` | jar / SSE / NameServer / Cursor 索引 |
| `probe-rocketmq-mcp-handshake.py` | `.cursor/.generated/probe-rocketmq-mcp-handshake.py` | MCP 协议 tools/list（114 工具） |
| `query-mq-via-mcp.py` | `.cursor/.generated/query-mq-via-mcp.py` | topic 积压 + `queryConsumeQueue` 样本 |
| `verify-mcp-dev.py` | `.cursor/.generated/verify-mcp-dev.py` | 轻量后端连通（TCP/认证/HTTP） |

```powershell
# 完整探测（推荐）；省略 profile 时使用 mcp.config.json 的 activeProfile
D:\miniconda3\python.exe .cursor\.generated\probe-mcp-dev.py
D:\miniconda3\python.exe .cursor\.generated\probe-mcp-dev.py sit
```

`verify-mcp-dev.py` 仅后端轻量探测（同上目录，需 `pip install pymysql redis`）。

```powershell
D:\miniconda3\python.exe .cursor\.generated\verify-mcp-dev.py

# rocketmq 专项
D:\miniconda3\python.exe .cursor\.generated\probe-rocketmq-mcp.py
D:\miniconda3\python.exe .cursor\.generated\probe-rocketmq-mcp-handshake.py
D:\miniconda3\python.exe .cursor\.generated\query-mq-via-mcp.py [TOPIC ...]
```

### sit 探测预期（2026-06 验证通过）

| 检查项 | 预期 |
|--------|------|
| MySQL auth | 8.0.x，多库（无 `MYSQL_DB` env） |
| Redis db2 dbsize | > 0 |
| Nacos naming API | sit namespace service count > 0 |
| XXL-Job login | `code=200`（含 accessToken yaml） |

### dev 探测预期（2026-06 验证通过）

| 检查项 | 预期 |
|--------|------|
| Loki `/ready` | `ready` |
| MySQL auth | 8.0.x |
| Redis db1 dbsize | > 0 |
| Nacos naming API | namespace 内 service count > 0 |
| XXL-Job login | `code=200` |
| ONES endpoint | HTTP 401/405（可达） |
| RocketMQ NS | `192.168.3.25:9876` TCP 可达 |
| rocketmq jar | `:6868` 监听；handshake 114 工具 |
| MCP 工具层 | loki/mysql/redis/xxl-job/nacos/ONES 均 Connected |

## XXL-JOB

profile.env 示例：

```json
"XXL_JOB_ADMIN_ADDRESS": "http://xxl-job.dev-ys-broker.com/xxl-job-admin",
"XXL_JOB_USERNAME": "admin",
"XXL_JOB_PASSWORD": "..."
```

switch 时 configurator 自动生成 `.cursor/.generated/xxl-job-<profile>.yaml`：

```yaml
xxl_job:
  admin_address: "http://xxl-job.dev-ys-broker.com/xxl-job-admin"
  username: "admin"
  password: "..."
mcp:
  transport: "stdio"
```

registry 启动命令：

```
uvx --with fastmcp==2.2.0 --from git+https://github.com/zz-wenzb/xxl-job-mcp xxl-job-mcp --config <yaml>
```

**注意**：

- 未发布 PyPI，必须从 GitHub 安装
- **必须 pin `fastmcp==2.2.0`**：新版 fastmcp 移除 `FastMCP(description=...)` 参数，不 pin 会 `TypeError: unexpected keyword argument 'description'`
- sit 环境若启用 accessToken，在 profile.env 设 `XXL_JOB_ACCESS_TOKEN`，configurator 会写入 yaml

抽样工具：`get_dashboard`、`list_executors`、`list_jobs`

## Nacos MCP Router

```json
"NACOS_ADDR": "192.168.3.25:8848",
"NACOS_USERNAME": "app",
"NACOS_PASSWORD": "...",
"NACOS_NAMESPACE": "802e8b2e-7a3e-419b-8fe2-b623130de0ff"
```

- **Router 模式**：`search_mcp_server` / `add_mcp_server` / `use_tool` — 搜索并代理 Nacos 注册的 MCP
- `search_mcp_server` 返回空 `{}` **正常**（尚未挂载子 server）
- `NACOS_NAMESPACE` 填 UUID（与 bootstrap-local / bootstrap-sit 一致）或 `public`

### Nacos 后端验证

| API | dev（app 账号） | 说明 |
|-----|-----------------|------|
| `/nacos/v1/auth/login` | ✅ | 获取 accessToken |
| `/nacos/v1/ns/service/list?namespaceId=<uuid>` | ✅ | 命名服务列表 |
| `/nacos/v1/cs/configs?tenant=<uuid>` | ⚠️ HTTP 500 | 可能是 app 账号无配置中心权限或 Nacos 版本行为；**不影响 MCP 进程连接** |

## Redis

registry 生成：

```json
"args": ["--from", "redis-mcp-server", "redis-mcp-server", "--url", "{{REDIS_URL}}"]
```

profile.env 示例（dev db1）：

```json
"REDIS_URL": "redis://:NKCMoPyC>CRzfn2oQ2qL@192.168.3.25:6379/1"
```

规则：

| 场景 | 正确格式 | 错误格式 |
|------|----------|----------|
| 无 ACL，仅 password | `redis://:password@host:port/db` | `redis://root:password@...` |
| 密码含 `>` | 原文写入 URL | `%3E` 编码 → `invalid username-password pair` |
| 密码含 `@` | URI 转义 `@` | 未转义导致 host 解析错误 |

## RocketMQ MCP

本地安装目录：**`D:\mcp/`**（与 Cursor 配置分离）

### 两层架构

| 层 | 位置 | 作用 |
|----|------|------|
| **jar 服务** | `D:\mcp\deploy\rocketmq-mcp-server.jar` | 独立 Java 进程，SSE `:6868` |
| **Cursor 客户端** | `~/.cursor/mcp.json` → `"url": "http://127.0.0.1:6868/sse"` | 仅 HTTP SSE，无 command/uvx |

### profile.env

| 变量 | 必填 | 说明 |
|------|------|------|
| `ROCKETMQ_MCP_URL` | ✅ | 通常 `http://127.0.0.1:6868/sse` |
| `ROCKETMQ_NS_ADDR` | ✅ | NameServer，如 `192.168.3.25:9876` |
| `ROCKETMQ_AK` / `ROCKETMQ_SK` | ❌ | 仅 RocketMQ 开启 ACL 时需要 |

switch 链路：`mcp-switch/scripts/switch-mcp-profile.ps1` → `restart-rocketmq-mcp.ps1` → `D:\mcp\restart-rocketmq-mcp.ps1`

- stop 旧 jar（commandLine / 端口 6868）
- `java -DNS_ADDR=... [-DAK=... -DSK=...] -jar ... --server.port=6868`
- 轮询最多 30s 等待监听
- 从 `servers` 移除 `rocketmq-mcp` 后 switch 仅 stop jar

### 构建与部署

```powershell
# 需 Java 17+（build.ps1 固定 D:\jdk\jdk17）
D:\mcp\rocketmq-mcp\build.ps1
```

Maven 使用 `D:\mcp\settings-build.xml`。产物：`D:\mcp\deploy\rocketmq-mcp-server.jar`

### 本地补丁（无 ACL 必做）

上游 `AdminUtil.validateRequiredParameters` 强制 AK/SK；无 ACL 时 `queryRecentMessages` 等返回 `ak不能为空`。

已在 `D:\mcp\rocketmq-mcp\src\...\AdminUtil.java` 改为仅校验 NameServer；改后须 **rebuild + restart**。

### 消息查询

| 场景 | 工具 / 脚本 | 说明 |
|------|-------------|------|
| topic 列表 | `fetchAllTopicList` | ~1000+ topic |
| 队列积压 | `examineTopicStats` | Java 风格 JSON，regex 解析 offset |
| 队列样本 | `queryConsumeQueue` | offset/size；body 常为 null |
| 按 key/时间 | `queryRecentMessages` | 需 message key |
| 按 msgId | `viewMessage` | 需 topic + msgId |

```powershell
D:\miniconda3\python.exe .cursor\.generated\query-mq-via-mcp.py
D:\miniconda3\python.exe .cursor\.generated\query-mq-via-mcp.py ORDER_SERVER_TOPIC_DEV
```

dev topic 命名：`OPERATE_LOG_TOPIC_DEV`、`ORDER_SERVER_TOPIC_DEV` 等（见 `RocketMQConstants.java`）。

### Cursor 索引

- jar 协议正常（handshake 114 工具 ~0.1s）
- `mcps/user-rocketmq-mcp/STATUS.md` 可能出现（114 工具 `tools/list` timeout）
- **以 jar 探测为准**；Reload 后仍 Error → Disable → Enable
- Cursor 请求协议 `2025-11-25`，jar 回退 `2024-11-05`

手动重启：`D:\mcp\restart-rocketmq-mcp.ps1 -NsAddr 192.168.3.25:9876 -Profile dev`

## Elasticsearch（可选，默认关闭）

[elastic/mcp-server-elasticsearch](https://github.com/elastic/mcp-server-elasticsearch) — `ES_URL` + `ES_API_KEY` 或用户名密码；`npx -y @elastic/mcp-server-elasticsearch`。

## Loki

推荐 stdio + 二进制：

```json
"tools": { "LOKI_MCP_BIN": "C:\\...\\loki-mcp.exe" },
"profiles.dev.env": { "LOKI_URL": "http://192.168.3.25:3100" }
```

验证：`curl http://<host>:3100/ready` → `ready`。

## MySQL

- `MYSQL_DB` 空字符串：多库模式（configurator 会**省略**该 env 字段）。**dev 与 sit 均使用多库**（sit 实例上无名为 `SIT` 的库，勿填 `MYSQL_DB="SIT"`）。
- configurator 对 `{{PLACEHOLDER}}` 会解析 env 中的空字符串并省略对应 env 键。
- 写操作默认关；需 `ALLOW_INSERT_OPERATION=true` 等（慎用）。

## codegraph

- 固定 MCP，stdio 启动 `codegraph serve --mcp --path ${workspaceFolder}`
- 工作区无 `.codegraph/` 索引时 **0 工具**，INSTRUCTIONS 显示 inactive
- 启用：项目根 `codegraph init`，新开会话

## 飞书

**禁止** `feishu-mcp`。用 `lark-cli` + Skills。

## 故障排查

| 现象 | 原因 | 处理 |
|------|------|------|
| Not connected | 未 Reload | Reload Window |
| uvx/npx 找不到 | PATH | `tools` 绝对路径 |
| redis → 127.0.0.1 | 未用 REDIS_URL / 旧进程 | 确认 mcp.json 有 `--url`；Reload |
| redis 认证失败 | `root:` 前缀或 `%3E` | 改为 `redis://:password@...`；密码原文 |
| mysql Unknown database | 库名错误 | `MYSQL_DB` 留空（多库）；勿填不存在的库名 |
| loki Connection closed | 二进制/URL | `LOKI_MCP_BIN`、`LOKI_URL`、/ready |
| ONES 无工具 | 未 OAuth | MCP 面板授权 |
| ES 报错 | 版本/协议/认证 | 见 ES 小节；7.x 可能不兼容官方包 |
| xxl-job 启动失败 | fastmcp 版本不兼容 | registry 已 pin `fastmcp==2.2.0`；Reload |
| xxl-job 认证失败 | 地址/账号 | 校正 `XXL_JOB_*`；检查生成的 yaml |
| nacos router 空列表 | 路由型设计 | 用 naming API 验后端；按需 `add_mcp_server` |
| nacos-mcp-router 连不上 | 密码/namespace | `NACOS_ADDR`、`NACOS_NAMESPACE` |
| rocketmq-mcp 无工具 / STATUS.md | jar 未启动或 Cursor timeout | 先 `probe-rocketmq-mcp-handshake.py`；jar OK 则 Reload / Disable→Enable |
| rocketmq `ak不能为空` | 上游 AdminUtil 未 patch | 重建 `D:\mcp` 本地 jar（见 RocketMQ 小节） |
| rocketmq build 失败 Java 17 | JAVA_HOME=11 | `build.ps1` 已固定 `D:\jdk\jdk17` |
| rocketmq switch 报 6868 未监听 | 启动慢 | `restart-rocketmq-mcp.ps1` 已轮询 30s；查 `D:\mcp\logs\` |
| codegraph 0 工具 | 未索引 | `codegraph init` |

## 验证清单

1. `mcp-switch/scripts/switch-mcp-profile.ps1 <profile>` — 输出地址与预期一致；含 rocketmq 时 jar 已 restart
2. **Reload Window**
3. Settings → MCP 全 Connected（rocketmq 以 jar 探测为准）
4. 运行 `probe-mcp-dev.py` — 后端通过 + MCP 工具层 OK
5. 含 rocketmq 时：`probe-rocketmq-mcp-handshake.py` + 可选 `query-mq-via-mcp.py`
6. 抽样调用：`who_am_i` / `SELECT 1` / `dbsize` / `loki_label_names` / `get_dashboard`

## page-agent 共存

合并写入 `~/.cursor/mcp.json`；非 registry 管理的条目保留。自定义 MCP 若用 `npx`，建议也改为绝对路径。page-agent 报错不影响 mcp-install 管理的 dev 服务。

## 项目集成

Onboarding：`mcp-install/SKILL.md` → copy 配置 → `mcp-switch` switch → Reload → `probe-mcp-dev.py` → 抽样工具调用。

Agent 规则：`.cursor/rules/memory/mcp-environment.mdc`
