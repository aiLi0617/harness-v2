# Harness Engineering

> 最后更新：2026-05-29
> 仓库地址：http://139.159.207.40:29080/ai-dev-share/broker

---

## 1. 概述

**Harness Engineering** 是围绕 AI 编码 Agent 构建系统、工具、约束和反馈回路的工程学科，目标是让 Agent 可靠、高效地参与软件开发。

**核心公式：**

```
Agent = Model + Harness
```

- **Model** 提供智能
- **Harness** 让智能变得可用

**指导原则**（Mitchell Hashimoto, 2026）：

> 每当 Agent 犯了一个错误，就设计一个解决方案，让 Agent 再也不会犯同样的错。

这不是 Prompt Engineering，而是**面向 AI 的系统工程**——Harness 应随每次迭代持续增强。

---

## 2. 架构地图

Broker 项目采用 **Harness 三工作流渐进体系**，所有 AI 代理必须遵守以下架构：

```
.cursor/
├── AGENTS.md          # 顶层代理指令（本体系入口）
├── CLAUDE.md          # 通用行为准则
├── rules/             # 被动规则（自动加载）
│   ├── memory/        # 项目知识与编码规范（26 条）
│   ├── orchestration/ # 工作流与任务管理（6 条）
│   ├── feedback/      # 门禁守卫与质量保障（8 条）
│   └── execution/     # 操作权限与安全边界（2 条）
├── skills/            # 主动技能（按需调用）
├── agents/            # 子代理定义（由工作流调度）
├── workflows/         # 三个工作流的 YAML 编排
└── mcp/               # MCP 服务配置模板
```

### 规则优先级

当规则冲突时，按以下优先级：

1. **execution/** — 安全红线最高
2. **feedback/** — 门禁守卫其次
3. **orchestration/** — 工作流规则
4. **memory/** — 编码规范

### 核心原则

1. **渐进式信息披露** — 按需获取上下文，不一次性读取整个项目
2. **沙箱隔离** — 所有代码变更在 feature 分支进行，禁止直接修改主分支
3. **仓库即真理来源** — 规范、决策、状态以文件形式存在于仓库，不依赖对话记忆
4. **机械化执行约束** — 遵守 `rules/`，不依赖口头指示
5. **全局调试日志** — 每步调用 `harness-debug-logger` 记录执行轨迹

---

## 3. 七大核心组件

| # | 组件 | 说明 |
|---|------|------|
| 1 | Context Engineering | 为 Agent 提供代码库地图、约定和约束 |
| 2 | Architectural Constraints | 通过 linter 和结构测试强制执行架构模式 |
| 3 | Tools & MCP Servers | 通过 CLI 和 MCP 暴露内部工具 |
| 4 | Sub-Agents & Context Firewalls | 将复杂任务拆分为子任务，隔离上下文 |
| 5 | Hooks & Back-Pressure | Pre-commit hooks、测试运行器、构建验证 |
| 6 | Self-Verification Loops | 强制 Agent 在标记完成前验证自身工作 |
| 7 | Progress Documentation | 长期任务的进度文件和结构化追踪 |

---

## 4. 三个工作流

### 工作流 1：Bug 修复（最小集）

**定义文件：** `.cursor/workflows/bugfix.yaml`

```
触发 → 复现 Bug → 根因分析 → 编写修复 → 审查 → 验证 → 归档
```

| 资源类型 | 使用的资源 |
|---------|-----------|
| Agents | shared/implementer、shared/code-reviewer、shared/memory-consolidator、bugfix/bug-analyst、bugfix/ones-loki-trace-investigator |
| Skills | shared/harness-debug-logger、shared/verification-before-completion、bugfix/systematic-debugging、bugfix/test-driven-bugfix |
| MCP | ones-mcp（缺陷管理）、loki-mcp（可选，日志查询） |

### 工作流 2：代码重构（扩展 Bug 修复）

**定义文件：** `.cursor/workflows/refactoring.yaml`

```
触发 → 代码分析 → 制定方案 → 逐步重构 → 回归验证 → 质量审查 → 通用审查 → 验证 → 归档
```

在 Bug 修复基础上新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | refactoring/refactoring-planner、refactoring/code-quality-reviewer |
| Skills | refactoring/refactoring-planning、refactoring/safe-refactoring |
| Rules | + method-design、naming-conventions、change-implementation、change-scope-guard |

### 工作流 3：PRD 到测试（完整流程）

**定义文件：** `.cursor/workflows/feature-delivery.yaml`

```
[可选: 云文档导入] → 功能拆分 → 头脑风暴 → 概要设计 → [一致性审查]
→ [HLD→飞书→人工确认] → DDL/API → 详细设计 → [一致性审查]
→ [LLD→飞书→人工确认] → 实现计划 → 编码 → [规格审查] → [质量审查]
→ [通用审查] → 验证 → 收尾
```

在重构基础上新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | feature/prd-feature-split、feature/architect-hld、feature/lld-author、feature/implementation-planner、feature/db-ddl、feature/api-contract、feature/spec-reviewer、shared/consistency-reviewer |
| Skills | feature/brainstorming、feature/writing-plans、feature/feature-delivery-workflow、feature/hld-to-feishu、feature/lld-to-feishu |
| MCP | feishu-mcp、{env}-mysql-mcp、{env}-swagger-mcp |

**完整审查链：**

1. consistency-reviewer — 设计阶段交接时校验制品对齐
2. spec-reviewer — 实现完成后校验代码是否按 LLD 设计
3. code-quality-reviewer — 校验代码质量
4. code-reviewer — 最终审查

---

## 5. 制品链（Artifact Chain）

子代理会话隔离，通过文件交接保持上下游一致。所有制品存放在 `docs/artifacts/`：

| 制品 | 产出者 | 消费者 |
|------|--------|--------|
| prd-source.md | 云文档导入（可选） | prd-feature-split |
| feature-list.md | prd-feature-split | brainstorming, architect-hld |
| brainstorm-result.md | brainstorming | architect-hld |
| hld.md | architect-hld | db-ddl, api-contract, lld-author |
| ddl.md | db-ddl | lld-author |
| api-contract.md | api-contract | lld-author |
| lld.md | lld-author | implementation-planner, spec-reviewer |
| impl-plan.md | implementation-planner | implementer |
| root-cause.md | bug-analyst | implementer |
| decision-log.md | human-checkpoint | 所有下游子代理 |
| harness-debug.md | harness-debug-logger | 用户调试 |
| verification-report.md | verification-before-completion | 用户审阅 |

**每个子代理必须：**

1. 开始前先读取上游制品文件
2. 完成后将产出写入对应制品文件
3. 读取 decision-log.md 确保不违背已有决策
4. 向 harness-debug.md 追加执行日志

**归档规则：** 任务完成后，制品移入 `docs/artifacts/archive/{日期}-{任务简称}/`。

---

## 6. 审查与人工检查点

### 审查-修复闭环

1. 审查者输出结构化问题报告（阻塞 / 警告 / 建议三级）
2. 不通过时自动回退给对应代理修复
3. 修复后重新审查
4. 最多 5 轮，超限则标记【人工介入】暂停流程

### 人工检查点

遇到以下情况必须暂停问用户：

- 需求模糊
- 方案抉择
- 风险操作
- 超出范围
- 假设不确定

每次问答记录到 `docs/artifacts/decision-log.md`。

### 记忆固化

当用户重复纠正同类错误时，调度 memory-consolidator 子代理将纠正写入对应的 `.mdc` 规则文件。

---

## 7. MCP 服务

配置模板：`.cursor/mcp/mcp-template.json`（复制为 `.cursor/mcp.json` 后填入实际值）

| MCP | 用途 | 工作流 |
|-----|------|--------|
| ones-mcp | ONES 缺陷管理 | Bug 修复 |
| loki-mcp | Grafana Loki 日志查询 | Bug 修复（可选） |
| feishu-mcp | 飞书云文档/消息 | 功能交付 |
| dev-mysql-mcp | 开发环境数据库 | 功能交付 |
| dev-swagger-mcp | API 文档查询 | 功能交付（可选） |
| codegraph-mcp | 代码知识图谱（本地） | 通用（可选） |
| chrome-devtools-mcp | 浏览器调试 | 通用（可选） |

---

## 8. 快速上手

### 构建与测试

```bash
# 编译（在目标模块目录下）
mvn compile -q

# 运行测试
mvn test -q

# 指定模块（示例）
cd broker-orch/broker-operate-orch && mvn test -q
```

### 触发工作流

| 场景 | 入口 |
|------|------|
| 修复 Bug | 描述缺陷现象，引用 ONES 单号（如有） |
| 代码重构 | 说明重构范围与目标 |
| 新功能交付 | 提供 PRD 或飞书文档链接 |

### 关键文件速查

| 需求 | 文件 |
|------|------|
| 了解整体架构 | `.cursor/AGENTS.md` |
| 编码规范 | `.cursor/rules/memory/` |
| 工作流定义 | `.cursor/workflows/*.yaml` |
| MCP 配置 | `.cursor/mcp/mcp-template.json` |
| 诊断报告 | `项目/Harness Engineering 项目诊断报告.md` |

---

## 9. 项目成熟度评估

> 诊断日期：2026-04-02 | 综合评分：**4.6 / 10**

| Harness 组件 | 评分 | 关键差距 |
|-------------|------|---------|
| Context Engineering | **7/10** | CLAUDE.md 过长，缺构建命令速查 |
| Architectural Constraints | **1/10** | 无静态分析 / 架构测试工具 |
| Tools & MCP | **6/10** | 缺 Nacos MCP、项目专用 CLI |
| Sub-Agents | **8/10** | 最强项，Skills 链完整 |
| Hooks & Back-Pressure | **0/10** | 无 Git hooks、无 CI、测试全禁 |
| Self-Verification | **3/10** | 测试覆盖低，全局禁用 |
| Progress Documentation | **7/10** | 文档好但未转化为可追踪任务 |

### 三个系统性问题

**问题一：无牙的规则**

有详细架构规范，但无 Checkstyle / ArchUnit 等自动化强制执行，违规静默积累。

**问题二：静默的失败**

maven.test.skip=true + 无 CI + 无 hooks = 全盲飞行，提交无反馈。

**问题三：Agent 技能强但地基弱**

Sub-Agent 和 Skills 投入大，但缺乏测试、静态分析、CI 等执行层防护。

### 推荐修复路线

| Phase | 时间 | 关键行动 |
|-------|------|---------|
| Phase 0 | Day 1-2 | 启用测试、添加 .gitignore / .editorconfig |
| Phase 1 | Week 1 | 引入 Checkstyle + SpotBugs |
| Phase 2 | Week 2 | 引入 ArchUnit + GitLab CI Pipeline |
| Phase 3 | Week 3 | P0 回归测试 + Pre-commit Hook |
| Phase 4 | Week 4 | 拆分 CLAUDE.md、补充构建脚本 |
| Phase 5 | 长期 | Feign 契约测试、Issues 追踪、专用 Skills |

> **核心结论：** 先建执行层基础设施（Hooks + 测试 + 静态分析 + CI），再优化认知层（Context + Skills + 文档）。

---

## 10. 变更记录

| 日期 | 变更说明 |
|------|---------|
| 2026-05-29 | 初始化 Wiki 文档，同步仓库 Harness 体系概述、工作流、制品链与成熟度评估 |
