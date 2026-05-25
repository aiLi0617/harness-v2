# 第三方插件安装清单

> Harness 接入业务项目后，按需安装下列 **Cursor / Agent 第三方插件**。
> 与 Harness 内置 MCP 模板（`.cursor/mcp/mcp-template.json`）相互独立；MCP 密钥类服务见 README「接入业务项目」。

---

## 一键安装（推荐顺序）

完成 **Harness 接入** 后，按顺序执行：

| 步骤 | 动作 | 说明 |
|------|------|------|
| 1 | 安装 P-01 飞书 CLI | 需飞书企业应用权限 |
| 2 | 安装 P-02 CodeGraph | 在**业务项目**根目录执行 init 脚本 |
| 3 | 安装 P-03 Loki MCP | 需 Docker 或 Go；配置 Loki 地址；Docker 不可用时用 `-Mode binary` |
| 4 | 重启 Cursor | 使 MCP / 插件配置生效 |

**Windows（业务项目根目录）：**

```powershell
# 1. 飞书 CLI
npx @larksuite/cli@latest install

# 2. CodeGraph（<harness-path> 替换为 harness-v2 克隆路径）
powershell -File <harness-path>\.cursor\scripts\init-codegraph.ps1 -ProjectPath (Get-Location) -AcceptGitHooks

# 3. Loki MCP（<LOKI_URL> 替换为实际 Loki 地址；Docker 未启动时加 -Mode binary）
powershell -File <harness-path>\.cursor\scripts\init-loki-mcp.ps1 -LokiUrl http://192.168.3.25:3100
# 或：powershell -File ... -Mode binary -LokiUrl http://192.168.3.25:3100
```

**macOS / Linux：**

```bash
# 1. 飞书 CLI
npx @larksuite/cli@latest install

# 2. CodeGraph
bash <harness-path>/.cursor/scripts/init-codegraph.sh --accept-git-hooks "$(pwd)"

# 3. Loki MCP
bash <harness-path>/.cursor/scripts/init-loki-mcp.sh --loki-url http://192.168.3.25:3100 "$(pwd)"
```

---

## 安装前（共用前提）

在安装任一插件前，确认已完成：

- [ ] 已 clone `harness-v2`，并对目标业务项目执行 `link-cursor-config.ps1` / `.sh`
- [ ] 已将 `.cursor/mcp/mcp-template.json` 复制为 `.cursor/mcp.json`，并填入实际密钥
- [ ] 本机已安装 **Node.js**（含 `npx`）；CodeGraph 亦可使用官方独立安装包（见 P-02）
- [ ] 安装 Loki MCP 时需 **Docker Desktop**（推荐）或 **Go 1.16+**（见 P-03）
- [ ] 已在 Cursor 中**打开业务项目**作为工作区（非 harness 配置仓本身）
- [ ] 网络可访问 npm / 各插件官方源

---

## 安装后（共用收尾）

全部插件装完后：

- [ ] **重启 Cursor**（或重载 MCP）
- [ ] 在 Cursor MCP 面板确认相关服务已连接
- [ ] 在业务项目根目录确认插件产物（如 CodeGraph 的 `.codegraph/`）
- [ ] 用一条简单任务验证 Agent 能调用插件能力（如飞书搜文档、CodeGraph 查符号、Loki 查日志）

---

## P-01 飞书 CLI

| 项目 | 内容 |
|------|------|
| 用途 | AI 操作飞书：消息、云文档、日历、任务、通讯录等 |
| 仓库 | [feishu-cli](https://www.feishu.cn/feishu-cli) / `@larksuite/cli` |
| 支持 Agent | Claude Code、Codex、Cursor、Trae、GitHub Copilot、Windsurf 等 |

### 安装前

- [ ] 已有飞书企业账号，且管理员已开通所需 API 权限
- [ ] 明确使用 **user** 还是 **bot** 身份（安装器会引导配置）

### 安装

```bash
npx @larksuite/cli@latest install
```

按交互式安装器选择 **Cursor**，并完成 OAuth / 应用授权。

### 安装后

- [ ] 重启 Cursor
- [ ] 执行 `lark-cli auth login`（若安装器未自动完成登录）
- [ ] 在 Agent 中试一条飞书相关指令（如搜索云文档），确认权限正常

### 验证

- [ ] Agent 能列出或搜索飞书资源，无 `Permission denied`

### 卸载 / 备注

- 按 `@larksuite/cli` 官方文档执行 uninstall
- 企业场景权限问题需联系飞书管理员，非 Harness 范畴

---

## P-02 CodeGraph

| 项目 | 内容 |
|------|------|
| 用途 | 本地代码知识图谱：符号搜索、调用链、影响分析；减少 grep / 读文件 |
| 仓库 | [colbymchenry/codegraph](https://github.com/colbymchenry/codegraph) |
| 支持 Agent | Claude Code、Cursor、Codex CLI、opencode、Hermes Agent |
| Harness 脚本 | `.cursor/scripts/init-codegraph.ps1` / `.sh` |

### 安装前

- [ ] 已在**业务 Java 项目**（含源码）根目录执行本清单，而非仅在 harness-v2 配置仓
- [ ] 项目 `.cursor/mcp.json` 已存在（来自 mcp-template）；脚本会自动合并 `codegraph-mcp` 段
- [ ] 了解 `.codegraph/` 为本地索引目录，**勿提交 Git**（业务项目 `.gitignore` 建议加入 `.codegraph/`）

### 安装

**推荐（Harness 一键脚本）：**

```powershell
# Windows
powershell -File <harness-path>\.cursor\scripts\init-codegraph.ps1 -ProjectPath <业务项目路径> -AcceptGitHooks
```

```bash
# macOS / Linux
bash <harness-path>/.cursor/scripts/init-codegraph.sh --accept-git-hooks <业务项目路径>
```

脚本依次：检测/安装 CLI → 配置用户级 Cursor MCP → 合并 `codegraph-mcp` → `codegraph init -i` → 输出 `status`。

**可选参数：**

| 参数 | 说明 |
|------|------|
| `-SkipGlobalMcp` / `--skip-global-mcp` | 本机已配过 Cursor MCP 时跳过 |
| `-SkipGlobalCli` / `--skip-global-cli` | 不装全局 CLI，全程 npx |
| `-ForceReindex` / `--force-reindex` | 已有 `.codegraph/` 时强制全量重建 |
| `-AcceptGitHooks` / `--accept-git-hooks` | 自动接受 git hooks（切分支 / merge 后自动 sync） |

**手动安装（备选）：**

```bash
npx @colbymchenry/codegraph install --target=cursor --yes
cd <业务项目> && codegraph init -i
```

### 安装后

- [ ] 重启 Cursor
- [ ] 确认业务项目根目录存在 `.codegraph/`
- [ ] 确认 `.cursor/mcp.json` 含 `codegraph-mcp`（或用户级 `~/.cursor/mcp.json` 含 codegraph）
- [ ] init 时若提示 git hooks，建议选择 **Yes**（切分支后索引自动更新）
- [ ] 日常改代码无需手动重算；MCP 连接时自动 sync

### 验证

- [ ] 在项目根执行 `codegraph status`，索引文件数 / 符号数 > 0（纯配置仓可能为 0，属正常）
- [ ] Agent 调用 `codegraph_search` 或 `codegraph_context` 能返回结果

### 卸载 / 备注

- 移除 Agent 配置：`codegraph uninstall`
- 移除项目索引：`codegraph uninit`（可选 `--force`）
- 无需 API Key；100% 本地 SQLite

---

## P-03 Loki MCP（Grafana）

| 项目 | 内容 |
|------|------|
| 用途 | 通过 LogQL 查询 Grafana Loki 日志；配合 `ones-loki-trace-investigator` 做缺陷 trace 排查 |
| 仓库 | [grafana/loki-mcp](https://github.com/grafana/loki-mcp) |
| 版本 | `v0.6.0`（脚本固定 tag） |
| Harness 脚本 | `.cursor/scripts/init-loki-mcp.ps1` / `.sh` |
| MCP 名称 | `loki-mcp`（与 `mcp-conventions.mdc` 一致） |
| 配置落点 | 优先写入用户级 `~/.cursor/mcp.json`；若存在项目 `.cursor/mcp.json` 则一并合并 |

### 安装前

- [ ] 已知 Loki API 地址（团队默认：`http://192.168.3.25:3100`）
- [ ] **Docker Desktop 已启动**（推荐），或本机已装 **Go 1.16+** 可编译二进制
- [ ] 若 Loki 需鉴权，向运维索取 `LOKI_ORG_ID` / `LOKI_TOKEN`（或用户名密码）
- [ ] 项目 `.cursor/mcp.json` 可选；无项目级文件时，用户级配置对本机所有工作区生效

### 安装

**推荐（Harness 一键脚本）：**

```powershell
# Windows（auto：Docker 可用则镜像，否则 Go 二进制）
powershell -File <harness-path>\.cursor\scripts\init-loki-mcp.ps1 -LokiUrl http://192.168.3.25:3100 -ProjectPath <业务项目路径>

# Docker 未启动时，强制二进制模式
powershell -File <harness-path>\.cursor\scripts\init-loki-mcp.ps1 -Mode binary -LokiUrl http://192.168.3.25:3100
```

```bash
# macOS / Linux
bash <harness-path>/.cursor/scripts/init-loki-mcp.sh --loki-url http://192.168.3.25:3100 <业务项目路径>
bash <harness-path>/.cursor/scripts/init-loki-mcp.sh --mode binary --loki-url http://192.168.3.25:3100
```

脚本依次：clone `grafana/loki-mcp@v0.6.0` 到系统临时目录 → 构建 Docker 镜像 `loki-mcp-server:latest` 或 Go 二进制 → 合并 `loki-mcp` 到 `~/.cursor/mcp.json`（及项目 `.cursor/mcp.json`，若存在）。

**运行模式与产物路径：**

| 模式 | 命令示例 | 产物 / 启动方式 |
|------|----------|-----------------|
| `docker`（推荐） | `-Mode docker` | 镜像 `loki-mcp-server:latest`，MCP 通过 `docker run --rm -i` 启动 |
| `binary` | `-Mode binary` | Windows：`%LOCALAPPDATA%\loki-mcp\loki-mcp-server.exe`；macOS/Linux：`~/.local/share/loki-mcp/loki-mcp-server` |
| `auto`（默认） | 省略 `-Mode` | Docker daemon 可用 → docker；否则 → binary |

**可选参数：**

| 参数 | 说明 |
|------|------|
| `-Mode docker` / `--mode docker` | 强制 Docker |
| `-Mode binary` / `--mode binary` | 强制 Go 二进制 |
| `-SkipBuild` / `--skip-build` | 仅合并 MCP 配置（镜像/二进制须已存在） |

**手动安装（备选）：**

Docker：

```bash
git clone --depth 1 --branch v0.6.0 https://github.com/grafana/loki-mcp.git
cd loki-mcp && docker build -t loki-mcp-server:latest .
```

Go 二进制（国内网络建议加代理）：

```powershell
# Windows
$env:GOPROXY = "https://goproxy.cn,direct"
git clone --depth 1 --branch v0.6.0 https://github.com/grafana/loki-mcp.git $env:TEMP\loki-mcp
cd $env:TEMP\loki-mcp
go build -o "$env:LOCALAPPDATA\loki-mcp\loki-mcp-server.exe" ./cmd/server
```

再将 `mcp-template.json` 中 `loki-mcp` 段复制到 `~/.cursor/mcp.json`（或项目 `.cursor/mcp.json`），替换 `<YOUR_LOKI_URL>`；binary 模式时将 `command` 改为上述二进制绝对路径。

### 安装后

- [ ] **重启 Cursor**（MCP 配置变更后必须重启）
- [ ] MCP 面板中 `loki-mcp` 显示已连接（非 Error）
- [ ] 确认 `loki-mcp.env.LOKI_URL` 指向可达的 Loki API
- [ ] 需要鉴权时，在 `mcp.json` 的 `loki-mcp.env` 中补充 `LOKI_ORG_ID` / `LOKI_TOKEN` 等

**MCP 配置示例（binary 模式，已实测）：**

```json
"loki-mcp": {
  "command": "C:\\Users\\<user>\\AppData\\Local\\loki-mcp\\loki-mcp-server.exe",
  "args": [],
  "env": {
    "LOKI_URL": "http://192.168.3.25:3100"
  }
}
```

### 验证

**Agent / MCP 工具验证：**

- [ ] `loki_label_names` 返回 label 列表（如 `namespace`、`job`、`app`、`pod` 等）
- [ ] `loki_query` 传入 `{job=~".+"}` 或 `{namespace="sit"} |= "ERROR"` 能返回日志或「无匹配」（均表示链路通）
- [ ] 或触发 `ones-loki-trace-investigator` 代理，能根据 traceId 拉到日志

**2026-05-25 团队实测记录（Windows，binary 模式）：**

| 步骤 | 结果 |
|------|------|
| Docker Desktop 未启动 | 脚本 `-Mode auto` 失败；改 `-Mode binary` + `GOPROXY=https://goproxy.cn,direct` 编译成功 |
| 合并 MCP 配置 | 写入 `~/.cursor/mcp.json`，`LOKI_URL=http://192.168.3.25:3100` |
| `loki_label_names` | 成功，返回 12 个 label |
| `loki_query` `{job=~".+"}` limit=3 | 成功，返回 `dev-cicd/broker-common-module-gateway` 实时日志（含 traceId） |

### 常见问题

| 现象 | 处理 |
|------|------|
| `docker info` 报 daemon 未运行 | 启动 Docker Desktop，或改用 `-Mode binary` |
| `go build` 访问 `proxy.golang.org` 超时 | 设置 `$env:GOPROXY="https://goproxy.cn,direct"` 后重编 |
| MCP 面板 Error / 工具不可用 | 重启 Cursor；确认二进制路径存在或 Docker 镜像已 build |
| 查询返回「无匹配」 | 链路通常仍正常；换 `{job=~".+"}` 或扩大时间范围再试 |
| 多租户 Loki 403 / 空结果 | 在 `env` 中补充 `LOKI_ORG_ID` 或 `LOKI_TOKEN` |

### 卸载 / 备注

- 从 `~/.cursor/mcp.json`（及项目 `mcp.json`）删除 `loki-mcp` 段
- Docker 镜像：`docker rmi loki-mcp-server:latest`
- Go 二进制：删除 `%LOCALAPPDATA%\loki-mcp\`（或 `~/.local/share/loki-mcp/`）
- 源码缓存：系统临时目录下的 `loki-mcp/`（脚本 clone 位置）
- 工具：`loki_query`、`loki_label_names`、`loki_label_values`
- 无需 API Key；Loki 地址与鉴权由 `env` 配置

---

## P-04 Understand Anything（可选）

| 项目 | 内容 |
|------|------|
| 用途 | 多 Agent 分析代码库，生成交互式知识图谱 + Dashboard；新人上手、架构可视化 |
| 仓库 | [Lum1104/Understand-Anything](https://github.com/Lum1104/Understand-Anything) |
| 中文文档 | [README.zh-CN.md](https://github.com/Lum1104/Understand-Anything/blob/main/READMEs/README.zh-CN.md) |
| Harness 脚本 | `.cursor/scripts/init-understand-anything.ps1` |
| 与 CodeGraph 关系 | **可选、互补**：CodeGraph 供 Agent 运行时查符号/调用链；UA 供人类看架构图与业务领域视图 |

### 安装前

- [ ] 本机已安装 **Node.js 20+**、**Git**（构建需 `pnpm`，脚本会通过 corepack 启用）
- [ ] 在**业务 Java 项目**根目录执行（非纯配置仓）；Harness 配置仓可试装但图谱价值有限
- [ ] 首次 `/understand` 会消耗较多 LLM token（全量分析）

### 安装

```powershell
# Windows（<业务项目路径> 替换为实际路径）
powershell -File <harness-path>\.cursor\scripts\init-understand-anything.ps1 -ProjectPath <业务项目路径>
```

脚本依次：clone 到 `%USERPROFILE%\.understand-anything\repo` → `pnpm install && build` → 链接 `%USERPROFILE%\.understand-anything-plugin` → 在项目根创建 junction：`.cursor-plugin`、`understand-anything-plugin`。

**可选参数：**

| 参数 | 说明 |
|------|------|
| `-SkipBuild` | 跳过 pnpm build（全局 checkout 已构建时） |
| `-Force` | 覆盖已有 junction |

### 安装后

- [ ] **重启 Cursor**
- [ ] 在已 wiring 的业务项目中，Agent 可用斜杠命令（见下方）
- [ ] 分析产物写入业务项目 `.understand-anything/`（可提交给团队，见官方 gitignore 说明）

### 使用（Cursor 斜杠命令）

```text
/understand --language zh          # 生成中文知识图谱
/understand-dashboard              # 打开交互式 Dashboard
/understand-chat <问题>            # 对话式问架构
/understand-domain                 # 业务领域视图
/understand-onboard                # 新成员指南
```

### 验证

- [ ] Cursor 插件面板可见 **Understand Anything**
- [ ] 在业务项目执行 `/understand --language zh`，生成 `.understand-anything/knowledge-graph.json`
- [ ] `/understand-dashboard` 能打开可视化页面

### 卸载 / 备注

- 删除项目根 junction：`.cursor-plugin`、`understand-anything-plugin`
- 删除全局：`%USERPROFILE%\.understand-anything\`、`.understand-anything-plugin`
- 项目分析产物：删除 `.understand-anything/`（若不需要保留图谱）
- **勿将 junction 目录提交 Git**（Harness 已在 `.gitignore` 忽略）

---

## 规划中的插件

新插件在此登记 ID 与安装命令，格式与上文 P-01 / P-02 保持一致。

| ID | 插件 | 安装命令 | 说明 |
|----|------|----------|------|
| — | （待补充） | — | — |

---

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-05-25 | 初版：飞书 CLI、CodeGraph |
| 2026-05-25 | 新增 P-03 Loki MCP（grafana/loki-mcp）及 init-loki-mcp 脚本 |
| 2026-05-25 | P-03 补充实测：binary 模式、goproxy 排障、验证步骤与团队连通性记录 |
| 2026-05-25 | 新增 P-04 Understand Anything（可选）及 init-understand-anything 脚本 |
