# Broker 项目技术债务登记册

| 项目 | 内容 |
|------|------|
| 文档版本 | v0.1 |
| 飞书云文档 | https://www.feishu.cn/docx/EezKdZq4qorEb1xsBekctxOnnUc |
| 更新日期 | 2026-06-04 |
| 适用范围 | `broker` 单体仓库（Maven 多模块） |
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

**命名约定（Nacos `spring.application.name`）**

| 类型 | 命名模式 | 示例 |
|------|----------|------|
| 网关 | `{场景}-gateway-server` | `operate-gateway-server` |
| 编排 | `{场景}-orch-server` | `operate-orch-server` |
| 能力 | `{领域}-biz-server` | `settlement-biz-server` |
| 公共 | `common-{能力}-biz-server` | `common-express-biz-server` |

---

### 1.2 面向业务的服务清单（用户可见系统）

以下按**业务门户 / 使用方**归纳，并映射到仓库模块与注册名。

| 业务名称 | 说明 | 网关模块 | 编排模块 | Nacos 服务名 |
|----------|------|----------|----------|----------------|
| **运营后台** | 经纪商 SaaS 运营端：租户、会员、要约、订单、结算、钱包、站点、权限等 | `broker-operate-gateway` | `broker-operate-orch` | `operate-gateway-server` / `operate-orch-server` |
| **商家前台** | 采购商/商家 C 端：登录注册、购物车、下单、要约浏览、收藏等 | `broker-business-frontend-gateway` | `broker-business-frontend-orch` | `business-frontend-gateway-server` / `business-frontend-orch-server` |
| **商家后台** | 供应商/商家 B 端：企业、产品、要约、订单、钱包、合同、发票、售后等 | `broker-business-backend-gateway` | `broker-business-backend-orch` | `business-backend-gateway-server` / `business-backend-orch-server` |
| **门户 / 官网** | 经纪商门户站：首页场景、资讯、横幅、数据看板、广告位等（编排层含独立 DAL） | `broker-portal-gateway` | `broker-portal-orch` | `portal-gateway-server` / `portal-orch-server` |
| **经纪人 / 代理端** | 代理用户、推广订单、分润月结、提现审批等 | —（多经 operate 或独立域名） | `broker-agent-orch` | `agent-orch-server` |
| **开放 API** | 对云商/外部系统的同步回调与开放接口（要约、订单、结算、合同等） | `broker-open-api-gateway` | `broker-api-orch` | `open-api-gateway-server` / `api-orch-server` |
| **登记结算（RGST）回调** | 登记结算平台异步回调入口 | `broker-rgst-api-gateway` | `broker-rgst-api-orch` | `rgst-api-gateway-server` / `rgst-api-orch-server` |
| **WebSocket / 站内信** | 站点消息推送、在线通知 | `broker-websocket-gateway` | `broker-websocket-orch` | `websocket-gateway-server` / `websocket-orch-server` |
| **公共模块网关** | 字典、物流、编码等 common 能力统一入口 | `broker-common-module-gateway` | — | `common-module-gateway-server` |

> **能力层（非独立门户，但被多个 Orch 依赖）**

| 业务名称 | 说明 | 能力模块 | Nacos 服务名 |
|----------|------|----------|----------------|
| **结算服务** | 订单、母订单、支付单、购物车、物流、发票、售后、交易流水等 | `broker-module-settlement-biz` | `settlement-biz-server` |
| **要约 / 挂牌服务** | 合约、SKU、调价记录、库存、快照、物流（listing 域） | `broker-module-listing-biz` | `listing-biz-server` |
| **产品服务** | 正式品/草稿品、SKU、规格、快照、云商结构同步 | `broker-module-product-biz` | `product-biz-server` |
| **认证服务** | OAuth2、多端登录、API 签名校验 | `broker-module-auth-biz` | `auth-biz-server` |
| **运营用户服务** | 运营账号、租户、站点配置、费用规则、资金统计 | `broker-module-operate-user-biz` | `operate-user-biz-server` |
| **商家会员服务** | 企业会员、注册审核、商家用户/角色/菜单、商家钱包 | `broker-module-member-user-biz` | `member-user-biz-server` |
| **运营钱包服务** | 经纪商侧钱包、结算渠道、子账户、经纪商资金统计 | `broker-module-operate-wallet-biz` | `operate-wallet-biz-server` |
| **代理服务** | 代理用户、推广单、等级、分润与提现 | `broker-module-agent-biz` | `agent-biz-server` |
| **用户收藏 / 咨询** | 要约收藏、咨询单 | `broker-module-user-collect-biz` | `user-collect-biz-server` |
| **基础服务** | 文件、字典、短信、合同模板、合同签署、隐私模板、站点模板 | `broker-module-base-biz` | `base-biz-server` |

---

### 1.3 公共与支付相关服务（common-modules）

| 服务名 | 模块路径 | 职责摘要 |
|--------|----------|----------|
| `common-bank-dict-biz-server` | `broker-common-module-bank-dict` | 银行字典 |
| `common-code-biz-server` | `broker-common-module-code` | 编码/流水号 |
| `common-express-biz-server` | `broker-common-module-express` | 物流 |
| `common-log-biz-server` | `broker-common-module-log` | 日志 |
| `common-operate-statistics-biz-server` | `broker-common-module-operate-statistics` | 运营侧统计 |
| `common-user-statistics-biz-server` | `broker-common-module-user-statistics` | 用户侧统计 |
| `common-cmb-client-server` | `broker-common-cmb-client` | 招行 CMB 客户端 |
| `common-yunshang-client-server` | `broker-common-yunshang-client` | 云商 HTTP 客户端 |
| `common-rgst-client-server` | `broker-common-rgst-client` | 登记结算客户端 |
| `common-sub-account-module-biz-server` | `broker-common-sub-account-module` | 子账户能力 |
| `common-sub-account-orch-server` | `broker-common-sub-account-orch` | 子账户编排 |
| `common-transaction-manager-module-server` | `broker-common-transaction-manager-module` | 交易事务管理 |
| `common-transaction-manager-orch-server` | `broker-common-transaction-manager-orch` | 交易事务编排 |
| `common-condominium-biz-server` | `broker-common-condominium-module` | 共管/共管账户相关 |
| `common-condominium-orch-server` | `broker-common-condominium-orch` | 共管编排 |

---

### 1.4 调度与其它运行时

| 名称 | 模块 | 说明 |
|------|------|------|
| WebSocket 调度 | `broker-scheduler-biz/broker-websocket-scheduler` | 站点日志 Redis 扫描推送（含 `KEYS` 等实现，见债务扫描） |
| 定时任务（分散） | 主要在 `broker-operate-orch` 的 `job` 包 | 订单费用划转、RGST 退款、银行回单、结算查询、产品同步重试等 |

---

## 二、各服务内部模块内容

> 下列「模块」指 **Controller 业务域（Orch）** 或 **ApiImpl / Service 业务域（BIZ）**，便于对照代码目录与排期债务治理。

---

### 2.1 运营后台 — `operate-orch-server`

**代码根路径**：`broker-orch/broker-operate-orch`  
**API 前缀**：`/admin-api/orch-layer/operate/...`  
**特点**：体量最大（约 900+ 编排 Java 文件），Feign 依赖多能力服务；含大量 `job` 定时任务。

| 模块域（controller/admin） | 主要内容 |
|---------------------------|----------|
| `tenant` | 多租户、域名与租户解析 |
| `site` | 站点配置、经纪商入口校验、域名类型 |
| `login` / `register` / `captcha` | 运营登录、注册、验证码 |
| `user` / `permission` / `menu` / `dept` / `accrole` | 运营用户、权限、菜单、部门、角色 |
| `member` / `memberoperate` | 会员管理、会员运营操作 |
| `product` | 产品库、正式品/草稿品（运营侧） |
| `agreement` | 要约挂牌、合约、订单（运营视角）、结算页 |
| `order` | 订单处理、费用事件相关编排 |
| `contract` / `contracttemplate` | 合同签署、合同模板 |
| `wallet` / `fundaccount` / `bank` / `pay` | 运营钱包、资金账户、银行、支付 |
| `transaction` / `unknownbill` | 交易流水、不明来款 |
| `feeconfigure` | 云商/经纪商费用规则配置 |
| `configcategory` / `configdisplay` / `configapi` | 类目、展示、API 配置 |
| `dict` | 字典 |
| `invoice` | 发票 |
| `statistics` | 统计报表 |
| `notice` | 通知 |
| `file` | 文件上传 |
| `flow` | 审批流 |
| `appcenter` | 应用中心 |
| `consultation` / `aftersales` | 咨询、售后（运营侧） |
| `rgst`（service/job） | 登记结算资金划转、退款、服务费 Job |

**主要依赖能力服务**：`operate-user-biz`、`operate-wallet-biz`、`listing-biz`、`settlement-biz`、`product-biz`、`member-user-biz`、`auth-biz`、`base-biz`、`agent-biz` 等。

---

### 2.2 商家前台 — `business-frontend-orch-server`

**代码根路径**：`broker-orch/broker-business-frontend-orch`  
**API 前缀**：`/admin-api/orch-layer/businessfrontend/...`

| 模块域 | 主要内容 |
|--------|----------|
| `user` | 注册、登录、短信验证、用户资料 |
| `auth` | 认证相关 |
| `site` | 商家入口域名、租户解析 |
| `tenant` | 租户 |
| `agreement` | 要约浏览、交易合约 |
| `order` | 下单、交易订单 |
| `cart` | 购物车 |
| `favorite` | 要约收藏 |
| `configcategory` | 经营类目配置 |
| `dict` | 字典 |
| `captcha` | 验证码 |
| `consultation` | 咨询 |
| `privacy` | 隐私协议 |

**主要依赖**：`settlement-biz`（购物车/订单）、`listing-biz`、`member-user-biz`、`auth-biz`、`user-collect-biz`、`product-biz`、`base-biz`。

---

### 2.3 商家后台 — `business-backend-orch-server`

**代码根路径**：`broker-orch/broker-business-backend-orch`  
**API 前缀**：`/admin-api/orch-layer/businessbackend/...`

| 模块域 | 主要内容 |
|--------|----------|
| `company` | 企业信息 |
| `member` | 会员、开票信息 |
| `user` / `dept` / `menu` | 商家用户、部门、菜单 |
| `product` | 供应商产品、草稿 |
| `agreement` | 要约维护、订单、物流地址、合同文件 |
| `order` | 挂牌单、订单列表与操作 |
| `aftersales` | 售后申请 |
| `contract` / `contracttemplate` / `esign` | 合同签署、模板、e 签宝 |
| `wallet` | 商家钱包、银行卡、流水、提现 |
| `transaction` | 线下汇款、采销财务 |
| `invoice` | 挂牌/摘牌/订单发票 |
| `statistics` | 统计 |
| `favorite` | 收藏 |
| `dict` | 多类字典（业务/银行/地区等） |
| `configcategory` | 类目 |
| `site` | 站点 |
| `file` | 文件 |
| `notice` | 站内信 |

**主要依赖**：`member-user-biz`、`settlement-biz`、`listing-biz`、`product-biz`、`base-biz`、`auth-biz`。

---

### 2.4 门户 — `portal-orch-server`

**代码根路径**：`broker-orch/broker-portal-orch`  
**特点**：编排层 **自带 27 个 Mapper**（`dal/mysql`），门户数据未下沉到独立 `portal-biz`。

| 模块域 | 主要内容 |
|--------|----------|
| `homepage` | 首页赞助挂牌 |
| `scene` | 首页/专区/挂牌场景、品牌优选、场景展示 |
| `datasetting` | 市场数据、品类趋势配置 |
| `consult` | 资讯文章、菜单、顶栏、机器人条、自定义菜单、交易统计 |
| `banner` | 横幅、业务配置 |
| `agreement` | 门户广告位 |
| `premiumenterprise` | 优质企业 |
| `file` | 文件 |

---

### 2.5 经纪人端 — `agent-orch-server`

| 模块域 | 主要内容 |
|--------|----------|
| `user` | 代理用户 |
| `workbench` | 工作台 |
| `promotionorder` | 推广订单 |
| `income` | 分润、月账单、提现审批 |
| `level` | 代理等级 |
| `fundaccount` | 资产、银行卡 |
| `file` / `captcha` / `notice` | 文件、验证码、站内信 |

**主要依赖**：`agent-biz`、`auth-biz`、`base-biz`。

---

### 2.6 开放 API — `api-orch-server`

面向云商/外部同步，Controller 多继承 `BaseApiController`。

| 模块域 | 主要内容 |
|--------|----------|
| `trade` | 订单、要约、支付、物流、线下单、推广单、不明资金、合同纸质件等 |
| `agreementsku` | 合约 SKU |
| `contract` / `contracttemplate` | 合同签署、模板 |
| `settlement` | 云商对账（如 `StlmtYsChecking`） |
| `wallet` | 提现流水 |
| `member` | 会员审批结果等 |
| `operateuser` | 运营属性同步 |
| `categorysyncall` / `businesscategory` / `categorybindingattribute` | 类目全量/经营类目/属性绑定同步 |

---

### 2.7 RGST 回调 — `rgst-api-orch-server`

| 模块域 | 主要内容 |
|--------|----------|
| `rgst` | `RgstCallbackController` — 登记结算平台回调 |

---

### 2.8 WebSocket — `websocket-orch-server`

| 模块域 | 主要内容 |
|--------|----------|
| `notice` | 站点消息（管理端） |
| `sitelog` | 内部 `InnerSiteLogController`，供各 Orch `/inner/site-log/*` 调用 |

---

### 2.9 能力层各服务模块（BIZ）

#### 2.9.1 结算服务 — `settlement-biz-server`

| 子域（api 包） | 能力 |
|----------------|------|
| `order` | 订单、母订单、SKU、状态、流程、地址、物流、结算明细、操作日志 |
| `payment` | 支付单、母支付单 |
| `cart` | 购物车 |
| `transaction` | 交易流水、不明来款明细 |
| `salesapply` | 售后申请 |
| `invoice` | 订单发票明细 |
| `contract` | 交易合同签署信息 |

#### 2.9.2 要约服务 — `listing-biz-server`

| 子域 | 能力 |
|------|------|
| `agreement` | 合约、SKU、调价记录、库存、预约挂牌、邀请、快照 |
| `agreement/snapshot` | 合约/SKU/归属快照 |
| `order`（listing 内订单视图） | 与要约相关的订单能力（与 settlement 配合） |

#### 2.9.3 产品服务 — `product-biz-server`

| 子域 | 能力 |
|------|------|
| `product` | 正式品、草稿、文件、归属、时效状态 |
| `product/snapshot` | 产品全量快照（规格、SKU、属性等） |
| 云商同步 | 草稿文件重试、结构同步 API |

#### 2.9.4 认证服务 — `auth-biz-server`

| 子域 | 能力 |
|------|------|
| `oauth2` | Token、运营/商家/代理登录、设备、SaaS 登录 |
| `signature` | 开放 API / 银行 / 中信签名校验配置 |
| `auth` | 鉴权服务 |

#### 2.9.5 运营用户 — `operate-user-biz-server`

| 子域 | 能力 |
|------|------|
| `account` | 运营用户、租户、经纪商公司、部门、平台权限 |
| `infoconfig` | 站点、域名、类目、属性、费用规则、合同类型、支付类型、展示配置、应用中心 |
| `fundaccount` | 资金账户流水、日/月/年统计（`FundAccountStatisc*`） |

#### 2.9.6 商家会员 — `member-user-biz-server`

| 子域 | 能力 |
|------|------|
| `account/member` | 企业、会员注册/审核、开票、白名单、协议 |
| `account` | 用户、角色、菜单、部门、地址 |
| `wallet/fundaccount` | 商家钱包、银行卡、流水、提现、子账户 |

#### 2.9.7 运营钱包 — `operate-wallet-biz-server`

| 子域 | 能力 |
|------|------|
| `wallet` | 经纪商钱包、子钱包、结算渠道、中信子账户 |
| `wallet/strategy` | CMB / RGST 余额变更策略（`ChangStrategy` 命名） |
| `statistics` | 经纪商资金统计 |

#### 2.9.8 代理 — `agent-biz-server`

| 子域 | 能力 |
|------|------|
| `user` | 代理用户 |
| `promotionorder` | 推广订单 |
| `income` | 代理公司、等级、分润、月结、提现审批 |
| `asset` | 资产统计、银行卡、提现日志 |

#### 2.9.9 用户收藏 — `user-collect-biz-server`

| 子域 | 能力 |
|------|------|
| `favorite` | 要约收藏（含 Redis 列表） |
| `consultation` | 咨询单 |

#### 2.9.10 基础 — `base-biz-server`

| 子域 | 能力 |
|------|------|
| `file` | 文件 |
| `dict` | 字典项、地区 |
| `notice/sms` | 短信验证码、发送 |
| `notice/site` | 站点模板、站内信 |
| `contract` / `contracttemplate` | 合同签署、模板文件 |
| `privacy` | 隐私模板 |
| `application` | 应用模板 |

---

### 2.10 API 契约层（`broker-modules-api`）

与 BIZ 一一对应的 Feign 接口与 DTO（**非独立进程**），共 10 个模块：

`base-api`、`auth-api`、`operate-user-api`、`member-user-api`、`agent-api`、`user-collect-api`、`operate-wallet-api`、`product-api`、`listing-api`、`settlement-api`。

> 注意：`listing-api` 内含 `AgreementFeeHelperUtil`、`FeeUtils` 等费用计算工具，属于契约层掺入业务逻辑的已知债务点（详见后续章节）。

---

### 2.11 框架与依赖（非业务服务，债务关联项）

| 仓库模块 | 作用 |
|----------|------|
| `broker-dependencies` | BOM 版本管理 |
| `broker-common-framework` | Redis、RPC、Seata、监控、通用工具 |
| `broker-biz-framework` | Web、Security、Tenant、MyBatis、支付、短信、云商 HTTP、文件等 Starter |

---

## 三、服务依赖关系（简图）

<whiteboard type="blank"></whiteboard>

> 上图：网关 → 编排 → 能力层依赖关系（可在画板中展开）。文字摘要：operate/business-frontend/business-backend/portal/open-api/rgst/websocket 等网关分别路由至对应 orch；operate-orch 依赖 settlement、listing、product、member-user、operate-user、operate-wallet、agent、base、auth 等 biz 服务。

---

## 四、上下文摘要（供后续债务条目引用）

- 仓库为 **Java 11 + Spring Cloud** 多模块单体仓，默认 `maven.test.skip=true`。
- **编排层职责偏重**：`operate-orch`、`portal-orch` 尤为突出；`portal-orch` 含完整 DAL。
- **结算 / 订单 / 支付** 主数据在 `settlement-biz`；**要约 / 合约** 在 `listing-biz`；**双钱包** 在 `operate-wallet-biz` 与 `member-user-biz`。
- 已有扫描参考：`项目/Broker项目全面扫描分析报告.md`。

---

## 五、技术债务明细（待补充）

> 第二大部分将按服务/模块登记具体债务项（安全、性能、重复代码、契约漂移、测试缺口等），并标注优先级与责任人。  
> 当前会话已梳理的样例类别：SQL `${}`、网关 Token 透传、Redis KEYS、全表查询、循环 Feign、双份 CMB/钱包策略、API 层业务逻辑、TODO/FIXME 堆积、巨型 Service 类等。

### 债务条目模板

```markdown
### [债务编号] 标题
- **所属服务/模块**：
- **类型**：安全 | 架构 | 性能 | 可维护性 | 测试 | 规范
- **严重程度**：P0 | P1 | P2 | P3
- **现象**：
- **影响**：
- **建议治理**：
- **状态**：待确认 | 进行中 | 已关闭
```

---

*文档维护：架构/研发在新增服务或拆分模块时同步更新第一章、第二章；债务条目在第二章模块稳定后按模块增量写入第五章。*
