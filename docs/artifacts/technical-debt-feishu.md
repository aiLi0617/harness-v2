<callout emoji="📋" background-color="light-blue">
Broker 项目技术债务登记册 — 服务全景与模块清单（v0.1）。本地源文件：docs/artifacts/technical-debt.md
</callout>

| 项目 | 内容 |
|------|------|
| 文档版本 | v0.1 |
| 更新日期 | 2026-06-04 |
| 适用范围 | broker 单体仓库（Maven 多模块） |
| 维护说明 | 本文档按「服务全景 → 模块清单 → 债务条目」组织；第二大部分（具体债务项）待后续迭代补充 |

---

## 一、服务与模块全景

### 1.1 架构分层说明

项目采用 **网关（Gateway）→ 编排（Orch）→ 能力（BIZ）** 三层对外服务，辅以 **公共能力模块（common-modules）** 与 **框架（broker-common-framework / broker-biz-framework）**。

```text
[浏览器 / 云商 / 登记结算 RGST / 三方]
        ↓
broker-gateways（9 个网关，路由 + Token 解析）
        ↓
broker-orch（8 个编排应用，聚合 Feign、对外 Controller）
        ↓
broker-modules-biz（10 个能力服务，领域逻辑 + 持久化）
        ↓
MySQL / Redis / 云商 HTTP / 招行 CMB / RGST 等
```

**命名约定（Nacos spring.application.name）**

| 类型 | 命名模式 | 示例 |
|------|----------|------|
| 网关 | {场景}-gateway-server | operate-gateway-server |
| 编排 | {场景}-orch-server | operate-orch-server |
| 能力 | {领域}-biz-server | settlement-biz-server |
| 公共 | common-{能力}-biz-server | common-express-biz-server |

---

### 1.2 面向业务的服务清单（用户可见系统）

以下按**业务门户 / 使用方**归纳，并映射到仓库模块与注册名。

| 业务名称 | 说明 | 网关模块 | 编排模块 | Nacos 服务名 |
|----------|------|----------|----------|----------------|
| **运营后台** | 经纪商 SaaS 运营端：租户、会员、要约、订单、结算、钱包、站点、权限等 | broker-operate-gateway | broker-operate-orch | operate-gateway-server / operate-orch-server |
| **商家前台** | 采购商/商家 C 端：登录注册、购物车、下单、要约浏览、收藏等 | broker-business-frontend-gateway | broker-business-frontend-orch | business-frontend-gateway-server / business-frontend-orch-server |
| **商家后台** | 供应商/商家 B 端：企业、产品、要约、订单、钱包、合同、发票、售后等 | broker-business-backend-gateway | broker-business-backend-orch | business-backend-gateway-server / business-backend-orch-server |
| **门户 / 官网** | 经纪商门户站：首页场景、资讯、横幅、数据看板、广告位等（编排层含独立 DAL） | broker-portal-gateway | broker-portal-orch | portal-gateway-server / portal-orch-server |
| **经纪人 / 代理端** | 代理用户、推广订单、分润月结、提现审批等 | —（多经 operate 或独立域名） | broker-agent-orch | agent-orch-server |
| **开放 API** | 对云商/外部系统的同步回调与开放接口 | broker-open-api-gateway | broker-api-orch | open-api-gateway-server / api-orch-server |
| **登记结算（RGST）回调** | 登记结算平台异步回调入口 | broker-rgst-api-gateway | broker-rgst-api-orch | rgst-api-gateway-server / rgst-api-orch-server |
| **WebSocket / 站内信** | 站点消息推送、在线通知 | broker-websocket-gateway | broker-websocket-orch | websocket-gateway-server / websocket-orch-server |
| **公共模块网关** | 字典、物流、编码等 common 能力统一入口 | broker-common-module-gateway | — | common-module-gateway-server |

> **能力层（非独立门户，但被多个 Orch 依赖）**

| 业务名称 | 说明 | 能力模块 | Nacos 服务名 |
|----------|------|----------|----------------|
| **结算服务** | 订单、母订单、支付单、购物车、物流、发票、售后、交易流水等 | broker-module-settlement-biz | settlement-biz-server |
| **要约 / 挂牌服务** | 合约、SKU、调价记录、库存、快照 | broker-module-listing-biz | listing-biz-server |
| **产品服务** | 正式品/草稿品、SKU、规格、快照、云商结构同步 | broker-module-product-biz | product-biz-server |
| **认证服务** | OAuth2、多端登录、API 签名校验 | broker-module-auth-biz | auth-biz-server |
| **运营用户服务** | 运营账号、租户、站点配置、费用规则、资金统计 | broker-module-operate-user-biz | operate-user-biz-server |
| **商家会员服务** | 企业会员、注册审核、商家用户/角色/菜单、商家钱包 | broker-module-member-user-biz | member-user-biz-server |
| **运营钱包服务** | 经纪商侧钱包、结算渠道、子账户 | broker-module-operate-wallet-biz | operate-wallet-biz-server |
| **代理服务** | 代理用户、推广单、等级、分润与提现 | broker-module-agent-biz | agent-biz-server |
| **用户收藏 / 咨询** | 要约收藏、咨询单 | broker-module-user-collect-biz | user-collect-biz-server |
| **基础服务** | 文件、字典、短信、合同模板、合同签署 | broker-module-base-biz | base-biz-server |

---

### 1.3 公共与支付相关服务（common-modules）

| 服务名 | 模块路径 | 职责摘要 |
|--------|----------|----------|
| common-bank-dict-biz-server | broker-common-module-bank-dict | 银行字典 |
| common-code-biz-server | broker-common-module-code | 编码/流水号 |
| common-express-biz-server | broker-common-module-express | 物流 |
| common-log-biz-server | broker-common-module-log | 日志 |
| common-operate-statistics-biz-server | broker-common-module-operate-statistics | 运营侧统计 |
| common-user-statistics-biz-server | broker-common-module-user-statistics | 用户侧统计 |
| common-cmb-client-server | broker-common-cmb-client | 招行 CMB 客户端 |
| common-yunshang-client-server | broker-common-yunshang-client | 云商 HTTP 客户端 |
| common-rgst-client-server | broker-common-rgst-client | 登记结算客户端 |
| common-sub-account-module-biz-server | broker-common-sub-account-module | 子账户能力 |
| common-sub-account-orch-server | broker-common-sub-account-orch | 子账户编排 |
| common-transaction-manager-module-server | broker-common-transaction-manager-module | 交易事务管理 |
| common-transaction-manager-orch-server | broker-common-transaction-manager-orch | 交易事务编排 |
| common-condominium-biz-server | broker-common-condominium-module | 共管账户相关 |
| common-condominium-orch-server | broker-common-condominium-orch | 共管编排 |

---

### 1.4 调度与其它运行时

| 名称 | 模块 | 说明 |
|------|------|------|
| WebSocket 调度 | broker-scheduler-biz/broker-websocket-scheduler | 站点日志 Redis 扫描推送 |
| 定时任务（分散） | 主要在 broker-operate-orch 的 job 包 | 订单费用划转、RGST 退款、银行回单、结算查询、产品同步重试等 |

---

## 二、各服务内部模块内容

> 下列「模块」指 Controller 业务域（Orch）或 ApiImpl / Service 业务域（BIZ）。

### 2.1 运营后台 — operate-orch-server

**代码根路径**：broker-orch/broker-operate-orch  
**API 前缀**：/admin-api/orch-layer/operate/...  
**特点**：体量最大，Feign 依赖多能力服务；含大量 job 定时任务。

| 模块域 | 主要内容 |
|--------|----------|
| tenant / site | 多租户、站点、域名入口 |
| login / register / captcha | 运营登录注册 |
| user / permission / menu / dept / accrole | 用户与权限 |
| member / memberoperate | 会员管理 |
| product / agreement / order | 产品、要约、订单 |
| contract / contracttemplate | 合同 |
| wallet / fundaccount / bank / pay | 钱包与支付 |
| transaction / unknownbill | 流水、不明来款 |
| feeconfigure / configcategory / dict | 费用与配置 |
| invoice / statistics / notice / file / flow / appcenter | 发票、统计、通知等 |
| consultation / aftersales / rgst | 咨询售后、RGST Job |

**主要依赖**：operate-user-biz、operate-wallet-biz、listing-biz、settlement-biz、product-biz、member-user-biz、auth-biz、base-biz、agent-biz 等。

### 2.2 商家前台 — business-frontend-orch-server

模块域：user、auth、site、tenant、agreement、order、cart、favorite、configcategory、dict、captcha、consultation、privacy。

### 2.3 商家后台 — business-backend-orch-server

模块域：company、member、user、dept、menu、product、agreement、order、aftersales、contract、esign、wallet、transaction、invoice、statistics、favorite、dict、configcategory、site、file、notice。

### 2.4 门户 — portal-orch-server

**特点**：编排层自带 27 个 Mapper。模块域：homepage、scene、datasetting、consult、banner、agreement、premiumenterprise、file。

### 2.5 经纪人端 — agent-orch-server

模块域：user、workbench、promotionorder、income、level、fundaccount、file、captcha、notice。

### 2.6 开放 API — api-orch-server

模块域：trade、agreementsku、contract、settlement、wallet、member、operateuser、类目同步相关。

### 2.7 RGST 回调 — rgst-api-orch-server

模块域：rgst（登记结算平台回调）。

### 2.8 WebSocket — websocket-orch-server

模块域：notice、sitelog（站内信）。

### 2.9 能力层（BIZ）摘要

| 服务 | 子域 |
|------|------|
| settlement-biz | order、payment、cart、transaction、salesapply、invoice、contract |
| listing-biz | agreement、snapshot、order |
| product-biz | product、snapshot、云商同步 |
| auth-biz | oauth2、signature、auth |
| operate-user-biz | account、infoconfig、fundaccount |
| member-user-biz | account/member、account、wallet/fundaccount |
| operate-wallet-biz | wallet、strategy、statistics |
| agent-biz | user、promotionorder、income、asset |
| user-collect-biz | favorite、consultation |
| base-biz | file、dict、notice、contract、privacy、application |

### 2.10 API 契约层

共 10 个模块：base-api、auth-api、operate-user-api、member-user-api、agent-api、user-collect-api、operate-wallet-api、product-api、listing-api、settlement-api。

### 2.11 框架与依赖

broker-dependencies、broker-common-framework、broker-biz-framework。

---

## 三、服务依赖关系（简图）

<whiteboard type="blank"></whiteboard>

> 网关层（operate / business-frontend / business-backend / portal / open-api / rgst / websocket）→ 对应 Orch → 依赖 settlement、listing、product、member-user、operate-user、operate-wallet、auth、base 等 BIZ 服务。

---

## 四、上下文摘要

- Java 11 + Spring Cloud 多模块单体仓，默认 maven.test.skip=true。
- 编排层职责偏重：operate-orch、portal-orch（含完整 DAL）。
- 结算主数据在 settlement-biz；要约在 listing-biz；双钱包在 operate-wallet-biz 与 member-user-biz。

---

## 五、技术债务明细（待补充）

第二大部分将按服务/模块登记具体债务项。样例类别：SQL 拼接、网关 Token 透传、Redis KEYS、全表查询、循环 Feign、双份 CMB/钱包策略、API 层业务逻辑、TODO 堆积、巨型 Service 等。

### 债务条目模板

- **所属服务/模块**：
- **类型**：安全 | 架构 | 性能 | 可维护性 | 测试 | 规范
- **严重程度**：P0 | P1 | P2 | P3
- **现象** / **影响** / **建议治理** / **状态**

---

*维护：新增服务或拆分模块时同步更新第一、二章；债务条目按模块写入第五章。*
