# Harness 资源放置指南

## 决策顺序

新增内容前依次判断：

1. 是否定义一个可独立调度角色的职责、权限和交付契约？放入 Agent。
2. 是否是复杂、可复用、可选加载的方法、命令、模板或工具操作？放入 Skill。
3. 是否决定阶段触发、顺序、条件、并行、回退、资源绑定或制品状态？放入
   Workflow。
4. 是否应对所有匹配任务始终生效？放入 Rule。
5. 是否只是解释、示例或迁移记录？放入 `docs/`。

Agent 与 Skill 不需要成对。若岗位策略简短且无法独立复用，保留在 Agent；
不要为结构对称创建空 Skill。

## 目录

| 资源 | 目录 | 命名 |
|---|---|---|
| Agent | `.cursor/agents/{agent-name}.md` | 文件名与 frontmatter `name` 一致 |
| Skill | `.cursor/skills/{skill-name}/SKILL.md` | 目录名与 `name` 一致 |
| Workflow | `.cursor/workflows/*.yaml` | 用户入口名称保持稳定 |
| Rule | `.cursor/rules/*.mdc` | 按约束主题命名 |
| 活动制品 | `docs/artifacts/work/{task-id}/` | 按语义分类，不按角色分类 |
| 历史制品 | `docs/artifacts/archive/` | 归档后只读 |

Agent 和 Skill 使用扁平结构。不得引入 Agent/Skill Registry、alias、`domain`、
`tags` 或其他 Cursor 不消费的发现元数据。

## Agent 放置标准

Agent 必填角色与使命、权限与模式、输入、输出制品、完成标准、Skill 调用条件
和禁止事项。岗位原则、上下游交接、停止与升级条件按需增加。

Agent 可以说明输入输出语义，但不得复制 Workflow 的完整阶段链、条件、并行
和回退。质量 Agent 默认不设置 `model`；需要多模型验证时，用户可直接在对应
Agent frontmatter 手工增加 Cursor 支持的模型字段。

新增或调整 Agent 时加载 `harness-resource-authoring` Skill，并使用其
`references/agent-template.md`。

## Skill 放置标准

Skill 包含适用条件、前置条件、操作方法、工具命令、失败处理和输出模板。
完整调试方法、重构拆步、计划写法、测试驱动步骤和机械验证应放 Skill。

`feature-delivery-workflow` 是特殊入口 Skill，只允许包含：

- 灵活入口和缺失制品检查；
- 中断恢复；
- 资源冲突检测；
- 日志初始化。

Feature 八阶段编排只允许位于 `.cursor/workflows/feature-delivery.yaml` 与
`.cursor/workflows/feature-delivery/phase-*.yaml`。

新增或调整 Skill 时加载 `harness-resource-authoring`，frontmatter 只允许
`name` 和 `description`，且不创建 README 或空资源目录。

## Rule 放置标准

- frontmatter 固定为 `description`、`globs`、`alwaysApply`，字段顺序不可变化。
- 多个 glob 使用带引号的单行标量，不使用 YAML 列表。
- 正文必须包含“适用范围”“强制规则”“验证清单”。
- “禁止事项”“正确示例”“反例”按需增加，禁止使用“补充规则”等兜底章节。
- 项目 Rule 必须使用项目专属 glob 且 `alwaysApply: false`。
- 新增或调整 Rule 时加载 `harness-resource-authoring` 的 Rule 模板。
- 重复纠正先形成 `workflow/memory-change.md`，人工批准后才能归入正确语义章节。

## Workflow 放置标准

每个步骤统一提供 `id`、`description`、`agent`、`skills.required`、
`skills.on_demand`、`entry_artifacts.required`、`entry_artifacts.optional`、
`exit_artifacts`、`condition`、`next.on_pass` 和 `next.on_fail`。资源为空时仍
保留结构。

并行 phase 显式声明 `execution.mode: parallel` 与 `execution.join: all`；质量
专项 Reviewer 可用同一 `parallel_group`，最终门禁必须在所有应到报告完成后
串行执行。

## 制品放置标准

制品根为 `docs/artifacts/work/{task-id}/`：

- `context/`：外部输入和仓库上下文；
- `analysis/`：特性、根因、影响和日志分析；
- `design/`：Brainstorm、HLD、DDL、API、LLD；可执行 DDL/DML 脚本在 `design/sql/*.sql`（禁止写入业务仓库 SQL 目录）；
- `plans/`：实现、重构、测试和发布计划；
- `delivery/`：变更清单、发布链接、迁移和上线记录；无设计阶段的订正脚本在 `delivery/sql/*.sql`；
- `quality/evidence/`：编译、测试、覆盖率、Lint、扫描等机械证据；
- `quality/gates/{gate-id}/`：专项审查与最终裁决；
- `workflow/`：状态、决策、调试日志和审查路由。

质量报告不按轮次建目录。同一文件追加 `Check NNN`，机械报告追加
`Run NNN`；旧记录禁止覆盖。模板位于 `docs/templates/`。

## 变更检查

修改资源后至少执行：

```powershell
.\.cursor\scripts\check-harness-resources.ps1
.\.cursor\scripts\check-rule-cross-refs.ps1
.\.cursor\scripts\smoke-workflows.ps1
```

同时核对引用资源存在、Workflow 制品链闭合、当前资源无废弃名称或旧制品
根路径，并确保 `docs/artifacts/archive/` 未被修改。
