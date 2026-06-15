# Harness 工程 - 顶层代理指令

## 架构概述

本项目采用 Harness 三工作流渐进体系，所有 AI 代理必须遵守以下架构：

- **Rules**（`.cursor/rules/`）：按四层分类的被动规则，自动加载
  - 记忆层（`memory/`）：项目知识与编码规范，17 个规则
  - 编排层（`orchestration/`）：工作流与任务管理，6 个规则
  - 反馈层（`feedback/`）：门禁守卫与质量保障，8 个规则
  - 执行层（`execution/`）：操作权限与安全边界，2 个规则
- **Skills**（`.cursor/skills/`）：按工作流分组的主动技能，按需调用
- **Agents**（`.cursor/agents/`）：按工作流分组的子代理，由工作流调度
- **Workflows**（`.cursor/workflows/`）：三个工作流的 YAML 编排定义
- **MCP**（`.cursor/mcp/mcp-template.json`）：MCP 服务配置模板，项目级管理

## 核心原则

1. **渐进式信息披露**：不要一次性读取整个项目，按需获取上下文
2. **沙箱隔离**：所有代码变更必须在 feature 分支中进行，禁止直接修改主分支
3. **仓库即真理来源**：一切规范、决策、状态都以文件形式存在于仓库中，不依赖对话记忆
4. **机械化执行约束**：遵守 `rules/` 中的规则文件，不要依赖口头指示
5. **全局调试日志**：除非 workflow YAML 显式设置 `debug: false`，每个步骤必须调用 `harness-debug-logger` 技能记录执行轨迹

## 三个工作流（渐进包含）

### 工作流 1：Bug 修复（最小集）

定义文件：`.cursor/workflows/bugfix.yaml`

```
触发 → 复现 Bug → 根因分析 → 编写修复 → 审查 → 验证 → 归档
```

| 资源类型 | 使用的资源 |
|---------|-----------|
| Agents | `shared/implementer` `shared/code-reviewer` `shared/memory-consolidator` `bugfix/bug-analyst` `bugfix/ones-loki-trace-investigator` |
| Skills | `shared/harness-debug-logger`（全局） `shared/verification-before-completion` `bugfix/systematic-debugging` `bugfix/test-driven-bugfix` |
| Rules | memory: exception-handling, null-safety, logging, mcp-conventions |
| | orchestration: git-branch, git-commit（+ always: coding-standards-loader, stage-contracts） |
| | feedback: compilation-guard, lint-guard, test-guard, correction-detection, human-checkpoint（+ always: java-edit-self-check） |
| | execution: execution-boundary, environment-boundary |
| MCP | `ones-mcp`（涉及 ONES 缺陷时必需）、`loki-mcp`（可选，日志查询） |

### 工作流 2：代码重构（扩展 Bug 修复）

定义文件：`.cursor/workflows/refactoring.yaml`

```
触发 → 代码分析 → 制定方案 → 逐步重构 → 回归验证 → 质量审查 → 通用审查 → 验证 → 归档
```

继承 Bug 修复的全部资源（含 `shared/memory-consolidator`、`shared/harness-debug-logger`），新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | `refactoring/refactoring-planner` `refactoring/code-quality-reviewer` |
| Skills | `refactoring/refactoring-planning` `refactoring/safe-refactoring`（`shared/code-generation-guardian` 由 implementer 按需调用） |
| Rules | memory: + method-design, naming-conventions, comment-conventions |
| | orchestration: + change-implementation |
| | feedback: + change-scope-guard |

### 工作流 3：PRD 到测试（完整流程）

定义文件：`.cursor/workflows/feature-delivery.yaml`

```
[可选: 云文档导入] → 功能拆分 → 头脑风暴 → 概要设计 → [一致性审查] → [HLD→飞书→人工确认] → DDL/API → 详细设计 → [一致性审查] → [LLD→飞书→人工确认] → 实现计划 → 编码 → [规格审查] → [质量审查] → [通用审查] → 验证 → 收尾
```

继承重构的全部资源，新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | `feature/prd-feature-split` `feature/architect-hld` `feature/lld-author` `feature/implementation-planner` `feature/db-ddl` `feature/api-contract` `feature/spec-reviewer` `shared/consistency-reviewer` |
| Skills | `feature/brainstorming` `feature/writing-plans` `feature/feature-delivery-workflow` `feature/hld-to-feishu` `feature/lld-to-feishu` `shared/code-generation-guardian` |
| Rules | memory: 全部 17 条激活（含 tenant-isolation, mcp-conventions） |
| | orchestration: + task-decomposition |
| | feedback: + schema-guard |
| MCP | `feishu-mcp`（飞书云文档发布时必需）、`{env}-mysql-mcp`（涉及 DB 时）、`{env}-swagger-mcp`（可选） |

完整审查链：
1. `consistency-reviewer` — 设计阶段交接时校验制品对齐
2. `spec-reviewer` — 实现完成后校验代码是否按 LLD 设计
3. `code-quality-reviewer` — 继承自重构，校验代码质量
4. `code-reviewer` — 继承自 Bug 修复，最终审查

## 制品链（Artifact Chain）

子代理会话隔离，通过文件交接保持上下游一致。所有制品存放在 `docs/artifacts/`：

| 制品 | 产出者 | 消费者 |
|------|--------|--------|
| `prd-source.md` | 云文档导入（可选） | prd-feature-split |
| `feishu-doc-links.md` | hld-to-feishu / lld-to-feishu | 后续更新/用户参考 |
| `feature-list.md` | prd-feature-split | brainstorming, architect-hld |
| `brainstorm-result.md` | brainstorming | architect-hld |
| `hld.md` | architect-hld | db-ddl, api-contract, lld-author |
| `ddl.md` | db-ddl | lld-author |
| `api-contract.md` | api-contract | lld-author |
| `lld.md` | lld-author | implementation-planner, spec-reviewer |
| `impl-plan.md` | implementation-planner | implementer |
| `root-cause.md` | bug-analyst / ones-loki-trace-investigator | implementer |
| `decision-log.md` | human-checkpoint | 所有下游子代理 |
| `harness-debug.md` | harness-debug-logger | 用户调试 |
| `verification-report.md` | verification-before-completion | 用户审阅 |

**每个子代理的 prompt 必须包含**：
1. "开始前先读取上游制品文件"
2. "完成后将产出写入对应制品文件"
3. "读取 `decision-log.md` 确保不违背已有决策"
4. "向 `harness-debug.md` 追加执行日志"

## 审查-修复闭环

所有审查节点统一遵循闭环流程：
1. 审查者输出结构化问题报告（阻塞/警告/建议三级）
2. 不通过时自动回退给对应代理修复
3. 修复后重新审查
4. 最多 5 轮，超限则标记【人工介入】暂停流程

## 人工检查点

遇到以下情况必须暂停问用户（`feedback/human-checkpoint.mdc`）：
- 需求模糊、方案抉择、风险操作、超出范围、假设不确定

每次问答记录到 `docs/artifacts/decision-log.md`。

## 记忆固化

当用户重复纠正同类错误时（`feedback/correction-detection.mdc`），调度 `memory-consolidator` 子代理将纠正写入对应的 `.mdc` 规则文件。

## 制品归档

任务完成后，`docs/artifacts/` 根目录下所有 `.md` 文件移入 `archive/{日期}-{任务简称}/`，保持根目录干净。

## 规则优先级

当规则冲突时，按以下优先级：
1. `execution/` — 安全红线最高
2. `feedback/` — 门禁守卫其次
3. `orchestration/` — 工作流规则
4. `memory/` — 编码规范
