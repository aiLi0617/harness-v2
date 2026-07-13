# Harness 架构与运行模型

## 1. 设计目标

Harness 使用三个稳定用户入口组织 Bug 修复、行为保持重构和完整功能交付，保证
角色契约、实施方法、流程编排、强制规则和任务制品各有唯一权威来源。

架构目标包括：

- 角色可独立调度，权限和交付边界明确。
- 复杂方法按需加载，避免所有上下文常驻。
- Workflow 可恢复、可审计，并能验证制品生产消费链。
- 实现者与质量 Reviewer 上下文隔离。
- 多模型审查可以共享同一报告和裁决协议。
- 历史制品保持原样，现行任务彼此隔离。

## 2. 四层领域模型

| 层 | 负责 | 不负责 |
|---|---|---|
| Agent | 角色、权限、输入输出语义、完成标准、岗位策略 | 完整教程、工具手册和阶段编排 |
| Skill | 复杂且可复用的方法、命令、模板、工具操作 | 固定流程顺序和角色所有权 |
| Workflow | 触发、阶段、依赖、条件、并行、回退、资源与制品绑定 | 重复岗位方法论 |
| Rule | 跨任务持续生效的约束和红线 | 逐 Agent I/O 表 |

Agent 与 Skill 是多对多关系，也允许 Agent 没有专属 Skill。无设计 Skill 的岗位
在 Agent 内保留最低覆盖面、证据边界和升级条件，这些属于 `ROLE POLICY`，而
不是通用 HOW。

## 3. Workflow

三个入口位于 `.cursor/workflows/`：

- `bugfix.yaml`
- `refactoring.yaml`
- `feature-delivery.yaml`

Bugfix 首先写入 `workflow/intent-routing.md`。只有 ONES 链接或 Issue Key时默认
选择只读 `investigation`，在根因分析后结束；只有用户明确授权代码修复时才进入
计划、实现和质量门禁。排查意图不会被 Workflow 名称隐式扩大为修改权限。

Feature delivery 的八阶段定义位于 `.cursor/workflows/feature-delivery/`。入口
Skill 只处理灵活进入、缺失制品检查、中断恢复、资源冲突和日志初始化。

Workflow 使用 version 2 统一步骤字段：`id`、`description`、`agent`、
`skills.required`、`skills.on_demand`、`entry_artifacts.required`、
`entry_artifacts.optional`、`exit_artifacts`、`condition` 和 `next`。

步骤默认串行；并行阶段或审查组显式声明 `execution.mode: parallel` 与
`execution.join: all`。审查循环必须有最大次数、修复目标和耗尽后的人工检查点。

实现质量组由 `next` 指向 group ID 触发。主会话按 group 的 `members` fan-out，
依据 `routing_artifact` 将条件成员标记为启动或 `SKIPPED`；所有成员到达终态后
才允许进入 `join_target`。单个 Reviewer 的 `next` 不能绕过 join。

## 4. 质量委员会

实现变更必跑静态分析、逻辑正确性、可维护性和测试充分性审查。安全、数据并发、
生产可排查性和全链路一致性由变更风险路由触发。专项 Reviewer 并行运行，
`quality-gate-reviewer` 在所有应到报告完成后串行裁决。

专项发现统一包含问题 ID、`BLOCKER/WARNING/ADVISORY`、状态、证据、影响、修复
要求和置信度。最终结论只有：

- `PASS`
- `FAIL`
- `HUMAN_REQUIRED`

未解决 BLOCKER 或必跑报告缺失必须 FAIL；证据无法可靠裁决时必须进入人工检查
点，不能依靠票数或模型声望决定。

## 5. 制品与状态

运行时：

```text
artifact_root = docs/artifacts/work/{task-id}
```

制品按 `context`、`analysis`、`design`、`plans`、`delivery`、`quality` 和
`workflow` 分类。Workflow 是具体生产者、消费者和阶段顺序的唯一来源。

决策记录的完整路径为：

```text
docs/artifacts/work/{task-id}/workflow/decision-log.md
```

质量报告不建立轮次目录。专项审查在原文件追加 Check，机械证据追加 Run；旧
记录不可覆盖。任务完成后整个目录移动至
`docs/artifacts/archive/{date}-{task-id}/`。

## 6. 维护约束

- Agent 与 Skill 保持扁平，不建立 Registry 或 alias。
- 不增加 Cursor 不消费的 `domain`、`tags` 等元数据。
- 平台无关 Agent 名通过 description 保留 ONES、Loki 等发现关键词。
- 质量 Agent 默认不绑定模型，模型映射不进入 Workflow。
- `stage-contracts.mdc` 只保留跨阶段约束，不复制 Agent I/O。
- 完整模板位于 [`templates/`](templates/README.md)。
