# Broker 微服务分层架构图绘制规范

> **用途**：沉淀 Broker 平台 2.5D 分层架构图的领域模型、命名、视觉与生成流程。  
> **后续**：可据此拆分为 `.cursor/skills/architecture-diagram/SKILL.md` + `templates/`。  
> **参考实例**：`项目资料/build-scripts/dev/` 下 Mermaid / Prompt / PNG 成品。

---

## 1. 适用范围

| 适用 | 不适用 |
|------|--------|
| Broker 全量/分层微服务架构图（2D / 2.5D） | 单服务内部类图、时序图 |
| 技术文档、Wiki、HLD、对外宣讲材料 | ER 图（见 `er-diagram-spec.mdc`） |
| Mermaid 结构源 + AI 视觉渲染 | 业务流程 BPMN |

**触发词**（Skill `description` 可复用）：架构图、分层架构、2.5D、等距、微服务全景、ProcessOn、43 服务。

---

## 2. 真相源（强制）

生成或更新架构图前，**必须先对齐服务清单**，禁止凭记忆补服务名或端口。

| 优先级 | 来源 | 说明 |
|--------|------|------|
| 1 | 飞书 Base 服务清单 | [服务清单 Base](https://zfnyunshang.feishu.cn/base/Uu5jbosxDawkUms024JcGtTjnw7?table=tbl2dCTAM7lAqiyU&view=vewy2vbiS2) |
| 2 | 仓库 `broker-gateways/`、`broker-orch/`、`broker-modules-biz/`、`common-modules/` | 模块名与端口以 Base 为准，POM `<description>` 作中文描述参考 |
| 3 | `项目资料/build-scripts/dev/processon-broker-arch.mmd` | 当前已沉淀的结构快照 |

**服务总数**：当前为 **43 个可部署服务**（Gateway 9 + Orch 8 + Biz 10 + Common 15 + scheduler 1；客户端与基础设施/外部不计入 43）。

---

## 3. 分层模型

主链路 **自上而下**；支撑层 **底部三列并排**（非左侧竖条）。

```
┌─────────────────────────────────────────────────────────┐
│  L1  客户端层 · 多端接入          （5 入口，非部署服务）    │
├─────────────────────────────────────────────────────────┤
│  L2  Gateway 网关层 · 9 服务      50008–50017            │
├─────────────────────────────────────────────────────────┤
│  L3  Orch 编排层 · 8 服务         59808–59817            │
├─────────────────────────────────────────────────────────┤
│  L4  Biz 业务域层 · 10 服务       59110–59120            │
├─────────────────────────────────────────────────────────┤
│  L5  Common 公共层 · 15 服务      58110–58412            │
├──────────────┬──────────────────────┬───────────────────┤
│ 开发支撑      │ 基础设施 · 运行期      │ 外部系统 · 对接层  │
│ 编译期        │                      │                   │
└──────────────┴──────────────────────┴───────────────────┘
```

### 3.1 协议副标题（固定句式）

```
43 可部署服务 · HTTPS → /admin-api/orch-layer/* → /rpc-api/capa-layer/*
```

### 3.2 各层主题色（2.5D / 文档统一）

| 层 | 主题色 | 层标题 |
|----|--------|--------|
| L1 客户端 | 黄色 | 客户端层 · 多端接入 |
| L2 Gateway | 蓝色 | Gateway 网关层 · 9 服务 |
| L3 Orch | 紫色 | Orch 编排层 · 8 服务 |
| L4 Biz | 绿色 | Biz 业务域层 · 10 服务 |
| L5 Common | 红色 | Common 公共层 · 15 服务 |
| 开发支撑 | 橙色 | 开发支撑 · 编译期 |
| 基础设施 | 浅蓝 | 基础设施 · 运行期 |
| 外部系统 | 青色 | 外部系统 · 对接层 |

2.5D 渲染：平台顶面浅色、侧面同色加深，带圆角与阴影；服务块为小立体方块，上方可选图标。

---

## 4. 节点命名规范

### 4.1 标签格式（强制）

每个**部署服务**节点必须包含三段信息：

```
<中文职责描述>
<英文服务名/模块名> · <端口>
```

**Mermaid 节点示例**（换行用 `<br/>`）：

```text
商家前台网关<br/>business-frontend-gateway · 50010
```

**2.5D / AI Prompt 单行示例**：

```text
商家前台网关 business-frontend-gateway 50010
```

### 4.2 中文描述来源优先级

1. 飞书 Base「服务说明」列（若有）
2. 模块 POM `<description>`（去掉冗余「服务」重复）
3. 编排/网关职责文档（如扫描报告 § 职责）
4. 与业务方确认后写入本规范 § 补充记录

### 4.3 基础设施 / 外部系统

基础设施节点：**中文能力 + 英文名**，可无端口：

```text
注册配置<br/>Nacos
持久化<br/>MySQL
```

外部系统：**中文业务名**；登记结算系统标注为外部回调，非客户端入口。

### 4.4 禁止写法

| 禁止 | 原因 | 应改为 |
|------|------|--------|
| 仅英文模块名 `api-gateway 50008` | 文档读者以中文为主 | `API 服务网关<br/>api-gateway · 50008` |
| `Web / 小程序 / App` | 与现网不符 | `商家前台<br/>App · H5` |
| 客户端层单独画「注册系统」 | 非独立 C 端入口 | 外部层「登记结算系统」+ 虚线回调 `rgst-api-gateway` |
| 子图之间 `client --> gateway` 聚合连线 | Mermaid 易语法报错 | 具体节点到具体节点，如 `merchantFe --> bizFeGw` |

---

## 5. 客户端层规则（L1）

客户端层描述**接入入口**，不是可部署服务，**不计入 43**。

### 5.1 当前标准五入口（2026-05 修订）

| 客户端入口 | 说明 | 对应 Gateway |
|-----------|------|--------------|
| 商家前台 · App / H5 | 移动端 App 与 H5 | business-frontend-gateway · 50010 |
| 商家后台 | 商家管理端 | business-backend-gateway · 50011 |
| 运营后台 | 经纪商运营端 | operate-gateway · 50009 |
| Api 服务 | 内部/标准 API | api-gateway · 50008 |
| OpenAPI 服务 | 对外开放 API | open-api-gateway · 50015 |

### 5.2 主链路（实线）

```
商家前台(App/H5) → 商家前台网关 → 商家前台编排 → Biz/Common
商家后台         → 商家后台网关 → 商家后台编排
运营后台         → 运营后台网关 → 运营编排
Api 服务         → API 网关       → API 编排
OpenAPI 服务     → 开放 API 网关  → API 编排
```

### 5.3 辅助链路（虚线，可选）

| 起点 | 终点 | 含义 |
|------|------|------|
| 商家前台 | WebSocket 网关 | 长连接 / 站内通知 |
| 运营后台 | 门户网关 | 门户运营配置 |
| 登记结算系统（外部） | rgst-api-gateway | 外部回调，非 C 端入口 |

### 5.4 不在 L1 单独出现的网关

以下网关无独立「客户端」方块，但必须在 L2 完整画出：

- portal-gateway · 50012
- common-module-gateway · 50013
- websocket-gateway · 50014
- rgst-api-gateway · 50017

---

## 6. 连线与图例

### 6.1 线型语义

| 线型 | Mermaid | 含义 |
|------|---------|------|
| 实线 | `-->` | 同步请求 / 主业务调用 |
| 虚线 | `-.->` | 注册发现、配置、监控、消息、外部回调 |

### 6.2 图例（2.5D 图右下角）

```
实线 ── 请求调用
虚线 -·- 注册发现 / 配置 / 监控 / 消息 / 外部回调
```

### 6.3 Mermaid 结构约束

- 根图：`flowchart TB`
- 每层一个 `subgraph`，层内 `direction LR`
- 节点 ID：camelCase 英文缩写（如 `bizFeGw`），**展示名放引号内**
- 避免在 subgraph 标识符上使用复杂连线；跨层用**具名节点**连接

---

## 7. Mermaid 源文件规范

### 7.1 文件命名

| 文件 | 用途 |
|------|------|
| `{project}-broker-arch.mmd` | 结构真相源（可 diff、可导入 ProcessOn） |
| `{project}-ai-prompt.txt` | 2.5D 自然语言 Prompt |
| `{project}-architecture-2.5d.png` | 成品位图 |
| `processon-import-guide.md` | 人工操作说明（可选） |

Broker 实例前缀：`processon-` 历史命名可保留，新 Skill 建议统一为 `broker-arch-*`。

### 7.2 分层 subgraph 标题模板

```mermaid
subgraph gateway ["Gateway 网关层 · 9 服务"]
    direction LR
    ...
end
```

### 7.3 密度过高时的处理

- Common 15 服务：Mermaid 保持单行 `direction LR`；2.5D 图允许 **2–3 行**排布
- 不可为可读性删除服务；可缩小字号，不可合并端口不同的服务

---

## 8. 2.5D 视觉规范

### 8.1 整体

- **视角**：2.5D / 等距（isometric）
- **层次**：每层一块悬浮平台（厚度、圆角、阴影）
- **服务块**：平台上的小立方体，标签在块下方或侧面
- **流向**：主链路自上而下箭头；底部三支撑区水平并列

### 8.2 标题区

```
主标题：Broker B2B 经纪平台微服务架构图
副标题：43 可部署服务 · HTTPS → /admin-api/orch-layer/* → /rpc-api/capa-layer/*
```

### 8.3 可读性底线

- 43 个服务名**必须全部出现**（允许缩小字体，不允许用「等 N 个」省略）
- 中文描述不得 Machine Translate 臆造；与 Base 不一致时标「待确认」
- 静态 AI 生成 PNG **不可编辑**；需可编辑源时必须保留 `.mmd` 并走 ProcessOn 图形化编辑

---

## 9. AI Prompt 模板

生成 `{project}-ai-prompt.txt` 时按以下骨架填写；`【】` 内替换为实际清单。

```text
请生成一张 B2B 经纪平台（Broker）2.5D 等距分层微服务架构图，要求如下：

【整体风格】
- 2.5D / 等距透视，每层是悬浮的立体平台（有厚度、圆角、阴影）
- 每个服务是平台上的小立体方块，上方有图标，下方有中文描述 + 英文服务名 + 端口
- 主链路自上而下，层与层之间有向下箭头
- 底部三列并排：开发支撑（编译期）、基础设施（运行期）、外部系统（对接层）
- 底部加图例：实线=请求调用，虚线=注册发现/配置/监控/消息/外部回调

【标题】
Broker B2B 经纪平台微服务架构图
副标题：43 可部署服务 · HTTPS → /admin-api/orch-layer/* → /rpc-api/capa-layer/*

【第1层 客户端层 · 黄色 · 多端接入】（横向 5 个）
<从 §5.1 表格复制>

【第2层 Gateway 网关层 · 蓝色 · 9 服务】
<中文 英文名 端口，竖线分隔>

【第3层 Orch 编排层 · 紫色 · 8 服务】
...

【第4层 Biz 业务域层 · 绿色 · 10 服务】
...

【第5层 Common 公共层 · 红色 · 15 服务】
...

【底部左 开发支撑 · 橙色 · 编译期】
定时任务 scheduler 59701 | Feign 契约 module-*-api | 公共框架 common-framework | 业务框架 biz-framework

【底部中 基础设施 · 浅蓝 · 运行期】
注册配置 Nacos | 持久化 MySQL | 缓存 Redis | 消息队列 RocketMQ | 搜索 Elasticsearch | 事务链路 Seata/SkyWalking

【底部右 外部系统 · 青色 · 对接层】
招商银行 支付结算 | 云商平台 | 登记结算系统（外部回调经 rgst-api-gateway，非客户端入口）

【主链路示意】
<从 §5.2 复制>

【配色】每层不同主题色，平台顶面浅色、侧面深色，整体干净专业，适合技术文档。
```

---

## 10. 生成工作流（决策树）

```
开始
  │
  ├─ 服务清单有变更？
  │     └─ 是 → 更新 Base / 扫描模块 → 改 .mmd → 改 ai-prompt.txt
  │
  ├─ 需要可编辑源文件？
  │     ├─ 是 → ProcessOn Mermaid 导入 → 图形化编辑 → 保存账号 → 导出
  │     └─ 否 → 继续
  │
  ├─ 需要 2.5D 效果？
  │     ├─ 是 → 优先：ProcessOn AI 生成（需登录）
  │     │       备选：GenerateImage + §9 Prompt（静态 PNG，不可编辑）
  │     └─ 否 → Mermaid 预览 / mermaid-cli 导出 2D PNG
  │
  └─ 验收 §11 检查清单 → 写入文档 / Wiki / 归档
```

### 10.1 工具选型

| 工具 | 结构准确度 | 2.5D | 可编辑 | 备注 |
|------|-----------|------|--------|------|
| `*.mmd` + Mermaid 预览 | ★★★★★ | ★★ | ★★★★ | 结构真相源 |
| ProcessOn Mermaid + 图形化编辑 | ★★★★★ | ★★★ | ★★★★★ | 需微信登录保存 |
| ProcessOn AI 生成 | ★★★ | ★★★★ | ★★★★ | 需人工核对 43 服务 |
| GenerateImage 直接出图 | ★★★ | ★★★★ | ★ | 快速交付，难 diff |
| 飞书画板 Mermaid | ★★★★ | ★★ | ★★★ | `<whiteboard>` 勿用错误 token 写法 |
| Figma MCP 自动绘制 | ★★ | ★★ | ★★★ | 复杂全景易失败，不推荐默认 |

### 10.2 ProcessOn 无 MCP

社区包 `@processon/mcp-server-processon` **仅支持 Markdown→思维导图**，不适用于本架构图。Open API 为企业嵌入，非 Agent 默认路径。

---

## 11. 验收检查清单

完成任意一版架构图后，逐项勾选：

```
[ ] 服务总数 = 43（Gateway 9 + Orch 8 + Biz 10 + Common 15 + scheduler 1）
[ ] L1 客户端 = 5 入口，且无独立「注册系统」
[ ] 商家前台标注 App · H5，非 Web/小程序/App 混写
[ ] 每个部署服务节点含：中文 + 英文名 + 端口
[ ] L2–L5 服务名与飞书 Base 一致（含 rgst / portal / websocket / common-module）
[ ] 登记结算系统在「外部系统」，虚线连 rgst-api-gateway
[ ] 底部三列：开发支撑 | 基础设施 | 外部系统（水平并排）
[ ] 图例含实线/虚线说明
[ ] 副标题协议链正确
[ ] 已提交/归档：.mmd + ai-prompt.txt +（可选）.png
[ ] 静态 PNG 已注明「不可编辑，以 .mmd 为准」
```

---

## 12. 反模式与踩坑记录

| 现象 | 原因 | 处理 |
|------|------|------|
| Mermaid 预览报错 | subgraph 间聚合连线 | 改为节点级连线 |
| ProcessOn 保存失败 | 未登录 | 微信扫码后再图形化编辑/AI |
| 飞书 Wiki 画板空白 | `replace_range` 吞掉 `<whiteboard token>` | 用 `<whiteboard type="blank">` + `whiteboard +update` |
| 2.5D 图缺服务 | AI 省略 | 以 .mmd 为准人工补全或重生成 |
| Common 显示 14 个 | 漏 rgst-client 等 | 对照 Base 逐项数 |
| 客户端与网关 1:1 不全 | portal/ws/rgst 无 C 端 | 允许，但 L2 必须画全 9 网关 |

---

## 13. 产出物目录约定

**Broker 当前实例**（`项目资料/build-scripts/dev/`）：

| 文件 | 角色 |
|------|------|
| `processon-broker-arch.mmd` | 结构真相源 |
| `processon-ai-prompt.txt` | 2.5D Prompt |
| `broker-architecture-2.5d.png` | 成品 PNG |
| `processon-import-guide.md` | 导入与修订说明 |

**Skill 化后建议**：

```
.cursor/skills/architecture-diagram/
├── SKILL.md                      # 从本文 §1–§11 精简
├── ARCHITECTURE-DIAGRAM-SPEC.md  # 本文（完整规范）
├── templates/
│   ├── broker-arch.mmd.tpl
│   ├── ai-prompt.txt.tpl
│   └── acceptance-checklist.md
└── examples/
    └── broker/                   #  symlink 或复制 dev 下实例
```

---

## 14. Skill 转化指引

将本文转为 `SKILL.md` 时：

### 14.1 建议 frontmatter

```yaml
---
name: architecture-diagram
description: >-
  绘制 Broker 微服务 2.5D 分层架构图：维护 Mermaid 结构源、AI Prompt、
  验收 43 服务与客户端五入口。在用户要求架构图、分层架构、2.5D、
  ProcessOn、服务全景图时使用。
disable-model-invocation: true
---
```

### 14.2 SKILL.md 应保留的章节（精简版）

1. 读取真相源（Base + `.mmd`）
2. 节点命名 §4
3. 客户端五入口 §5
4. 更新 `.mmd` → 同步 `ai-prompt.txt`
5. 选择生成路径 §10 决策树
6. 跑验收清单 §11
7. 详细规范见 `ARCHITECTURE-DIAGRAM-SPEC.md`

### 14.3 可选自动化脚本（后续）

- `scripts/validate-arch-mmd.sh`：统计 subgraph 内节点数是否 = 43
- `scripts/sync-prompt-from-mmd.py`：从 mmd 提取标签写入 prompt 层清单

---

## 15. 补充记录（变更日志）

| 日期 | 变更 |
|------|------|
| 2026-05 | 客户端层：Web/小程序/App → 商家前台 App·H5；新增五入口；移除 L1 注册系统；全节点中文化 |
| 2026-05 | 首版 2.5D PNG 直接生成路径沉淀；ProcessOn 改为可选可编辑分支 |
| 2026-05 | 研发部团队组织图：研发部领导（张/罗）→ 经纪平台（刘）· 撮合平台（徐）；见 `broker-team-org.*` |

---

## 附录 B：研发部团队组织图（与微服务架构图分离）

| 文件 | 用途 |
|------|------|
| `项目资料/build-scripts/dev/broker-team-org.mmd` | 组织树 Mermaid 结构源 |
| `项目资料/build-scripts/dev/broker-team-org-ai-prompt.txt` | 2.5D 组织图 AI Prompt |
| `项目资料/build-scripts/dev/broker-team-org.png` | 2.5D 成品 |
| `项目资料/build-scripts/dev/broker-team-org.md` | 人员清单与平台线说明 |

**层级**：研发部领导 → 两个**独立平台线**（经纪 · 刘昌宏 / 撮合 · 徐煜东）→ 小组 → 成员。勿与微服务 Gateway/Orch 分层混淆。

---

## 附录 A：Broker 全量服务速查（与 .mmd 同步）

<details>
<summary>Gateway · 9</summary>

| 中文 | 英文 | 端口 |
|------|------|------|
| API 服务网关 | api-gateway | 50008 |
| 运营后台网关 | operate-gateway | 50009 |
| 商家前台网关 | business-frontend-gateway | 50010 |
| 商家后台网关 | business-backend-gateway | 50011 |
| 门户网关 | portal-gateway | 50012 |
| 公共模块网关 | common-module-gateway | 50013 |
| WebSocket 网关 | websocket-gateway | 50014 |
| 开放 API 网关 | open-api-gateway | 50015 |
| 登记结算 API 网关 | rgst-api-gateway | 50017 |

</details>

<details>
<summary>Orch · 8</summary>

| 中文 | 英文 | 端口 |
|------|------|------|
| API 编排 | api-orch | 59808 |
| 运营编排 | operate-orch | 59809 |
| 商家前台编排 | business-frontend-orch | 59810 |
| 商家后台编排 | business-backend-orch | 59811 |
| 门户编排 | portal-orch | 59812 |
| 经纪人编排 | agent-orch | 59813 |
| WebSocket 编排 | websocket-orch | 59814 |
| 登记结算 API 编排 | rgst-api-orch | 59817 |

</details>

<details>
<summary>Biz · 10</summary>

| 中文 | 英文 | 端口 |
|------|------|------|
| 基础能力 | base | 59110 |
| 认证 | auth | 59111 |
| 商家用户 | member-user | 59113 |
| 运营用户 | operate-user | 59114 |
| 经纪人 | agent | 59115 |
| 用户收藏 | user-collect | 59116 |
| 运营钱包 | operate-wallet | 59117 |
| 产品 | product | 59118 |
| 挂牌 | listing | 59119 |
| 结算 | settlement | 59120 |

</details>

<details>
<summary>Common · 15 + scheduler</summary>

| 中文 | 英文 | 端口 |
|------|------|------|
| 物流聚合 | express | 58110 |
| 操作日志 | log | 58111 |
| 银行字典 | bank-dict | 58112 |
| 商家统计 | user-statistics | 58113 |
| 运营统计 | operate-statistics | 58114 |
| 编号服务 | code | 58115 |
| 子账户编排 | sub-account-orch | 58210 |
| 交易编排 | transaction-manager-orch | 58211 |
| 共管编排 | condominium-orch | 58212 |
| 子账户 | sub-account | 58310 |
| 交易管理 | transaction-manager | 58311 |
| 共管支付 | condominium | 58312 |
| 招行接入 | cmb-client | 58410 |
| 云商接入 | yunshang-client | 58411 |
| 登记结算接入 | rgst-client | 58412 |
| 定时任务 | scheduler | 59701 |

</details>
