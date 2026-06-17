# Harness 工程 - 顶层代理指令

## 架构概述

本项目采用 Harness 三工作流渐进体系，所有 AI 代理必须遵守以下架构：

- **Rules**（`.cursor/rules/`）：被动规则，自动加载；自 2026-06 起已扁平化（无 `memory/`、`feedback/`、`orchestration/`、`execution/` 子目录），所有 `.mdc` 直接位于 `rules/` 根。原四层分类仅保留为语义标签，不再体现在目录结构中：
  - 记忆层（编码规范，约 28 条）
  - 编排层（工作流与任务管理，约 6 条）
  - 反馈层（门禁守卫与质量保障，约 9 条）
  - 执行层（操作权限与安全边界，2 条）
- **Skills**（`.cursor/skills/`）：主动技能，按需调用；自 2026-06 起已扁平化（无 `bugfix/`、`feature/`、`refactoring/`、`shared/` 子目录），每个 skill 直接位于 `skills/<skill-name>/SKILL.md`
- **Agents**（`.cursor/agents/`）：子代理，由工作流调度；自 2026-06 起已扁平化（无 `bugfix/`、`feature/`、`refactoring/`、`shared/` 子目录），每个 agent 直接位于 `agents/<agent-name>.md`。原四类分组仅保留为语义标签，不再体现在目录结构中
- **Workflows**（`.cursor/workflows/`）：三个工作流的 YAML 编排定义；`feature-delivery` 进一步按最小阶段拆到 `workflows/feature-delivery/phase-*.yaml`，由 `feature-delivery.yaml` 作为编排索引按顺序引用
- **MCP**（`.cursor/mcp/mcp-template.json`）：MCP 服务配置模板，项目级管理
- **Scripts**（`.cursor/scripts/`）：校验/初始化脚本（如 `check-rule-cross-refs.ps1` / `.sh`）
- **Plugins**（`.cursor/plugins/feature-list.md`）：第三方插件安装清单

> **项目特化资源**：harness 内置通用层全部扁平化直接挂在 `rules/`、`skills/`、`agents/` 根；针对单个业务项目的定制化规则/技能/代理统一收纳于各资源目录下的 `projects/<project>/` 子目录（按"作用域"分组，内部仍扁平），通过文件名 `<project>-` 前缀与 `globs` 共同锁定生效范围。详见 `rules-loader.mdc` 「项目特化规则加载约定」。

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
| Agents | `agents/implementer` `agents/code-reviewer` `agents/memory-consolidator` `agents/bug-analyst` `agents/ones-issue-fetcher` `agents/loki-log-investigator` |
| Skills | `skills/harness-debug-logger`（全局） `skills/done-verify` `skills/systematic-debug` `skills/tdd-bugfix` |
| Rules（按文件名引用，已扁平化） | always: `rules-loader` `stage-contracts` `correction-detection` `human-checkpoint` `java-edit-self-check` |
| | active: `exceptions` `null-safety` `logging` `git-branch` `git-commit` `compile-guard` `lint-guard` `test-guard` `execution-boundary` `environment-boundary` |
| MCP | `ones-mcp`（涉及 ONES 缺陷时必需）、`loki-mcp`（可选，日志查询） |

### 工作流 2：代码重构（扩展 Bug 修复）

定义文件：`.cursor/workflows/refactoring.yaml`

```
触发 → 代码分析 → 制定方案 → 逐步重构 → 回归验证 → 质量审查 → 通用审查 → 验证 → 归档
```

继承 Bug 修复的全部资源（含 `agents/memory-consolidator`、`skills/harness-debug-logger`），新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | `agents/refactoring-planner` `agents/code-quality-reviewer` |
| Skills | `skills/refactor-plan` `skills/safe-refactoring`（`skills/codegen-guard` 由 implementer 按需调用） |
| Rules（增量） | active: + `method-design` `naming` `comments` `change-implementation` `scope-guard` |

### 工作流 3：PRD 到测试（完整流程）

定义文件：`.cursor/workflows/feature-delivery.yaml`

```
[可选: 云文档导入] → 功能拆分 → 头脑风暴 → 概要设计 → [一致性审查] → [HLD→飞书→人工确认] → DDL/API → 详细设计 → [一致性审查] → [LLD→飞书→人工确认] → 实现计划 → 编码 → [规格审查] → [质量审查] → [通用审查] → 验证 → 收尾
```

继承重构的全部资源，新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | `agents/prd-splitter` `agents/architect-hld` `agents/lld-author` `agents/impl-planner` `agents/db-ddl` `agents/api-contract` `agents/spec-reviewer` `agents/consistency-reviewer` |
| Skills | `skills/brainstorming` `skills/writing-plans` `skills/feature-delivery-workflow` `skills/hld-to-feishu` `skills/lld-to-feishu` `skills/codegen-guard` |
| Rules（增量） | active: 原记忆层 28 条全部激活（含 `tenant-isolation` `mcp` `microservice` 等）+ `task-decomposition` `schema-guard` |
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
| `prd-source.md` | 云文档导入（可选） | prd-splitter |
| `feishu-doc-links.md` | hld-to-feishu / lld-to-feishu | 后续更新/用户参考 |
| `feature-list.md` | prd-splitter | brainstorming, architect-hld |
| `brainstorm-result.md` | brainstorming | architect-hld |
| `hld.md` | architect-hld | db-ddl, api-contract, lld-author |
| `ddl.md` | db-ddl | lld-author |
| `api-contract.md` | api-contract | lld-author |
| `lld.md` | lld-author | impl-planner, spec-reviewer |
| `impl-plan.md` | impl-planner | implementer |
| `root-cause.md` | bug-analyst | implementer |
| `issue-context-{key}.md` | ones-issue-fetcher | loki-log-investigator / bug-analyst |
| `root-cause-loki-{key}.md` | loki-log-investigator | implementer / bug-analyst |
| `decision-log.md` | human-checkpoint | 所有下游子代理 |
| `harness-debug.md` | harness-debug-logger | 用户调试 |
| `verification-report.md` | done-verify | 用户审阅 |

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

遇到以下情况必须暂停问用户（`human-checkpoint.mdc`）：
- 需求模糊、方案抉择、风险操作、超出范围、假设不确定

每次问答记录到 `docs/artifacts/decision-log.md`。

## 记忆固化

当用户重复纠正同类错误时（`correction-detection.mdc`），调度 `memory-consolidator` 子代理将纠正写入对应的 `.mdc` 规则文件。

## 制品归档

任务完成后，`docs/artifacts/` 根目录下所有 `.md` 文件移入 `archive/{日期}-{任务简称}/`，保持根目录干净。

## 规则优先级

当规则冲突时，按以下语义层级优先级（不再对应目录结构，仅作约束语义参考）：
1. 执行层（`execution-boundary.mdc` `environment-boundary.mdc`）— 安全红线最高
2. 反馈层（`*-guard.mdc` `correction-detection` `human-checkpoint` 等）— 门禁守卫其次
3. 编排层（`git-*` `change-implementation` `task-decomposition` `stage-contracts` `rules-loader`）— 工作流规则
4. 记忆层（其余编码规范类 `.mdc`）— 编码规范

## 规则加载原则

- **规则文件互不引用** — 每条规则自描述本领域约束，正文不写「见 xxx.mdc」
- **路由层负责组合** — 场景到规则的映射由 `rules-loader.mdc`、workflow YAML、globs 决定
- **Agents/Skills 通过 loader 发现规则** — 不硬编码 `rules/<file>.mdc` 路径（`memory-consolidator` 纠正写入路由除外）
