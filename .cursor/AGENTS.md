# Harness 工程 - 顶层代理指令

## 架构概述

本项目是 **Harness v2** 配置仓：`Agent = Model + Harness`。所有 AI 代理必须遵守以下五类资源与三工作流体系。

| 资源 | 路径 | 数量 | 加载方式 |
|------|------|------|----------|
| Rules | `.cursor/rules/` | 49 通用 + 13 broker 特化 | 被动，globs / alwaysApply |
| Skills | `.cursor/skills/` | 16 | 主动，任务触发 |
| Agents | `.cursor/agents/` | 16 | 工作流调度 |
| Workflows | `.cursor/workflows/` | 3 主流程 + 8 阶段文件 | 用户触发 |
| MCP | `skills/mcp-switch/` + `skills/mcp-install/` | 11 注册服务 | init-mcp / switch 生成 |

### Rules（`.cursor/rules/`）

自 2026-06 起已扁平化，所有 `.mdc` 直接位于 `rules/` 根。语义四层（非目录结构）：

- **记忆层**（编码规范，约 28 条）：命名、异常、日志、空值、API、数据库、测试等
- **编排层**（约 6 条）：Git、变更实施、任务拆解、阶段契约、规则加载器
- **反馈层**（约 9 条）：编译/Lint/测试门禁、Java 编辑自检、Schema、纠正检测、人工检查点
- **执行层**（2 条）：操作红线、环境边界

`rules/projects/<project>/` 存放项目特化规则（当前内置 broker 13 条），靠 `<project>-` 前缀 + `globs` 锁定范围。详见 `rules-loader.mdc`。

### Skills（`.cursor/skills/`）

每个 skill 位于 `skills/<skill-name>/SKILL.md`：

| 场景 | 技能 |
|------|------|
| 共享 | `harness-debug-logger` `done-verify` `git-worktree` `codegen-guard` |
| Bug 修复 | `systematic-debug` `tdd-bugfix` |
| 重构 | `refactor-plan` `safe-refactoring` |
| 功能交付 | `brainstorming` `writing-plans` `feature-delivery-workflow` `hld-to-feishu` `lld-to-feishu` |
| MCP | `mcp-switch` `mcp-install` `mcp-db` `mcp-dbx` |

### Agents（`.cursor/agents/`）

| 场景 | 代理 |
|------|------|
| 共享 | `implementer` `code-reviewer` `memory-consolidator` `consistency-reviewer` |
| Bug 修复 | `bug-analyst` `ones-issue-fetcher` `loki-log-investigator` |
| 重构 | `refactoring-planner` `code-quality-reviewer` |
| 功能交付 | `prd-splitter` `architect-hld` `db-ddl` `api-contract` `lld-author` `impl-planner` `spec-reviewer` |

### Workflows（`.cursor/workflows/`）

- `bugfix.yaml` — Bug 修复（最小集）
- `refactoring.yaml` — 代码重构（扩展 Bug 修复）
- `feature-delivery.yaml` — 功能交付编排索引 + `feature-delivery/phase-1..8.yaml`

### MCP（mcp-switch 技能体系）

| 文件 | 作用 |
|------|------|
| `skills/mcp-switch/mcp-registry.json` | MCP 服务启动模板 |
| 业务项目 `.cursor/mcp-workspace/mcp.workspace.json` | 环境、项目 path、profile servers（链接时复制，每项目独立） |
| 业务项目 `.cursor/mcp-workspace/mcp.workspace.secrets.json` | 密钥（链接时从 example 复制，勿提交 Git） |

生成流程：`init-mcp.ps1` / `switch-all-mcp-profiles.ps1` → 写入 `~/.cursor/mcp.json`。规范见 `rules/mcp.mdc`。

### 其他

- **Scripts**（`.cursor/scripts/`）：规则交叉引用校验等
- **Plugins**（`.cursor/plugins/feature-list.md`）：第三方插件安装清单

> **项目特化资源**：通用层扁平挂在 `rules/`、`skills/`、`agents/` 根；业务定制收纳于各目录下 `projects/<project>/`，由 `globs` 或 workflow 显式引用。

## 核心原则

1. **渐进式信息披露**：按需获取上下文，不要一次性读取整个项目
2. **沙箱隔离**：代码变更在 feature 分支进行，禁止直接改主分支
3. **仓库即真理来源**：规范、决策、状态以文件形式持久化，不依赖对话记忆
4. **机械化执行约束**：遵守 `rules/`，不依赖口头指示
5. **全局调试日志**：除非 workflow 设置 `debug: false`，每步调用 `harness-debug-logger`
6. **规则优先于参考实现**：Java 编码以已加载 rules 为准；同模块已有代码仅可参考分层与命名风格（见 `change-implementation`、`java-edit-self-check`）

## 接入业务项目

在业务项目根目录执行 `link-cursor-config.ps1` / `.sh`：

| 方式 | 资源 |
|------|------|
| **软链**（目录） | `.cursor/agents` `rules` `skills` `workflows` `scripts` `plugins`，`docs/` |
| **软链/硬链**（文件） | `.cursor/AGENTS.md`、`.cursor/CLAUDE.md`（Windows 硬链，Unix 软链） |
| **复制**（每项目独立） | `.cursor/mcp-workspace/mcp.workspace.json`、`.cursor/mcp-workspace/mcp.workspace.secrets.json` |

链接后配置 MCP：

1. 编辑 `.cursor/mcp-workspace/mcp.workspace.json`（`projects.local.path` 等）
2. 编辑 `.cursor/mcp-workspace/mcp.workspace.secrets.json`（密钥）
3. `powershell -File .cursor/skills/mcp-install/scripts/init-mcp.ps1 -Profile dev`
4. 日常切换：`switch-all-mcp-profiles.ps1 dev|sit|pre`

升级 harness：在 harness 仓 `git pull`，业务项目软链自动生效；`mcp-workspace/` 为本地副本，不被覆盖（除非 `-Force`）。

## 三个工作流（渐进包含）

### 工作流 1：Bug 修复

定义：`.cursor/workflows/bugfix.yaml`

```
触发 → 复现 Bug → 根因分析 → 编写修复 → 审查 → 验证 → 归档
```

| 资源类型 | 使用的资源 |
|---------|-----------|
| Agents | `implementer` `code-reviewer` `memory-consolidator` `bug-analyst` `ones-issue-fetcher` `loki-log-investigator` |
| Skills | `harness-debug-logger` `done-verify` `systematic-debug` `tdd-bugfix` |
| Rules always | `rules-loader` `stage-contracts` `correction-detection` `human-checkpoint` `java-edit-self-check` |
| Rules active | `exceptions` `null-safety` `logging` `git-branch` `git-commit` `compile-guard` `lint-guard` `test-guard` `execution-boundary` `environment-boundary` |
| MCP | `ones-mcp`（ONES 缺陷时）、`loki-mcp`（可选） |

### 工作流 2：代码重构

定义：`.cursor/workflows/refactoring.yaml`

```
触发 → 代码分析 → 制定方案 → 逐步重构 → 回归验证 → 质量审查 → 通用审查 → 验证 → 归档
```

继承 Bug 修复全部资源，新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | `refactoring-planner` `code-quality-reviewer` |
| Skills | `refactor-plan` `safe-refactoring`（`codegen-guard` 由 implementer 按需调用） |
| Rules | + `method-design` `naming` `comments` `change-implementation` `scope-guard` |

### 工作流 3：功能交付

定义：`.cursor/workflows/feature-delivery.yaml`（`entry_mode: flexible`）

```
[可选: 云文档导入] → 功能拆分 → 头脑风暴 → 概要设计 → [一致性审查] → [HLD→飞书]
  → DDL/API → 详细设计 → [一致性审查] → [LLD→飞书] → 实现计划 → 编码
  → [规格审查] → [质量审查] → [通用审查] → 验证 → 收尾
```

继承重构全部资源，新增：

| 资源类型 | 新增资源 |
|---------|---------|
| Agents | `prd-splitter` `architect-hld` `lld-author` `impl-planner` `db-ddl` `api-contract` `spec-reviewer` `consistency-reviewer` |
| Skills | `brainstorming` `writing-plans` `feature-delivery-workflow` `hld-to-feishu` `lld-to-feishu` `codegen-guard` |
| Rules | 记忆层 28 条全部激活 + `task-decomposition` `schema-guard` |
| MCP | `feishu-mcp`（飞书发布）、`{env}-mysql-mcp`、`{env}-swagger-mcp`（可选） |

**审查链**（4 层）：

1. `consistency-reviewer` — 设计阶段制品对齐（HLD 后、LLD 后）
2. `spec-reviewer` — 代码 vs LLD
3. `code-quality-reviewer` — 代码质量
4. `code-reviewer` — 最终审查

## 制品链（Artifact Chain）

子代理会话隔离，通过 `docs/artifacts/` 文件交接：

| 制品 | 产出者 | 消费者 |
|------|--------|--------|
| `prd-source.md` | 云文档导入（可选） | prd-splitter |
| `feishu-doc-links.md` | hld-to-feishu / lld-to-feishu | 用户参考 |
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

**每个子代理 prompt 必须包含**：

1. 开始前读取上游制品文件
2. 完成后写入对应制品文件
3. 读取 `decision-log.md` 确保不违背已有决策
4. 向 `harness-debug.md` 追加执行日志

## 审查-修复闭环

1. 审查者输出结构化报告（阻塞 / 警告 / 建议）
2. 不通过 → 回退对应代理修复 → 重新审查
3. 最多 5 轮，超限标记【人工介入】暂停

## 人工检查点

以下情况必须暂停问用户（`human-checkpoint.mdc`）：需求模糊、方案抉择、风险操作、超出范围、假设不确定。记录到 `docs/artifacts/decision-log.md`。

## 记忆固化

用户重复纠正同类错误时（`correction-detection.mdc`），调度 `memory-consolidator` 写入对应 `.mdc` 的「补充规则」章节。

## 制品归档

任务完成后，`docs/artifacts/` 根目录 `.md` 移入 `archive/{日期}-{任务简称}/`。

## 规则优先级

1. 执行层（`execution-boundary` `environment-boundary`）
2. 反馈层（`*-guard` `correction-detection` `human-checkpoint`）
3. 编排层（`git-*` `change-implementation` `task-decomposition` `stage-contracts` `rules-loader`）
4. 记忆层（其余编码规范 `.mdc`）

## 规则加载原则

- 规则文件互不引用，每条自描述本领域约束
- 场景映射由 `rules-loader.mdc`、workflow YAML、globs 决定
- Agents/Skills 通过 loader 发现规则，不硬编码路径（`memory-consolidator` 写入路由除外）
