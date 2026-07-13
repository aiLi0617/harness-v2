# Cursor Harness 资源约定

## 领域边界

- Agent = WHO + WHAT + CONTRACT + ROLE POLICY。
- Skill = REUSABLE / OPTIONAL / COMPLEX HOW。
- Workflow = WHEN + ORDER + BINDING + STATE。
- Rule = ALWAYS-APPLICABLE CONSTRAINT。

Agent 不必机械配对 Skill。Agent 正文只保留角色、权限、输入语义、输出内容
要求、完成标准、Skill 调用条件和禁止事项；完整方法、命令、模板及工具步骤
放入 Skill。阶段顺序、并行、回退和人工检查点只放入 Workflow。

## Agent

业务与治理 Agent：

`issue-context-fetcher`、`log-investigator`、`requirements-analyst`、
`problem-analyst`、`solution-architect`、`database-designer`、`api-designer`、
`detail-designer`、`implementation-planner`、`refactoring-planner`、
`implementer`、`memory-consolidator`。

质量委员会：

`static-analysis-reviewer`、`logic-correctness-reviewer`、
`maintainability-reviewer`、`diagnosability-reviewer`、
`consistency-reviewer`、`security-reviewer`、`test-adequacy-reviewer`、
`data-concurrency-reviewer`、`quality-gate-reviewer`。

质量 Agent 默认省略 `model`。专项 Reviewer 只写自己的报告；
`quality-gate-reviewer` 在所有应到报告完成后追加唯一裁决。

## Workflow

用户入口固定为 `bugfix`、`refactoring`、`feature-delivery`。所有步骤统一声明：

- `id`、`description`、`agent`
- `skills.required`、`skills.on_demand`
- `entry_artifacts.required`、`entry_artifacts.optional`
- `exit_artifacts`、`condition`
- `next.on_pass`、`next.on_fail`

资源可以为空，但结构不得省略。路径相对 Workflow 的 `artifact_root`。默认
串行；并行阶段显式使用 `execution.mode: parallel` 和
`execution.join: all`。审查循环必须声明最大次数、修复目标和耗尽后的人工
检查点。

### parallel_group fan-out / join

- `next.on_pass` 指向 `parallel_groups` 中的 group ID 时，Workflow 主会话必须对
  `members` 做 fan-out，不能只启动第一个成员。
- `routing_artifact` 决定条件成员是否启动；必跑成员始终启动，未触发的条件成员
  记录为 `SKIPPED`，不得伪造专项报告。
- 每个已启动成员独占自己的输出文件，并把终态发送到 `{group-id}.join`。
- `execution.join: all` 要求所有成员达到 `PASSED`、`FAILED` 或 `SKIPPED`；
  运行中、缺失或未知状态均不得解锁 `join_target`。
- `join_target` 只能在全部应到报告存在后启动。专项成员失败仍先完成 join，再由
  `quality-gate-reviewer` 基于报告中的 BLOCKER 作最终裁决。
- fan-out、条件跳过、成员终态和 join 结果必须追加到 `workflow/workflow-state.md`
  与 `workflow/harness-debug.md`。

### 主会话生产制品

- `context/repository-context.md` 由 `refactoring-planner` 生产，不得由初始化步骤
  临时拼装。
- `workflow/review-routing.md` 由主会话加载 `quality-review-routing` Skill 生产；
  没有该 Skill 或输入与实际 diff 不一致时必须停止。

## 制品与质量协议

所有新任务写入 `docs/artifacts/work/{task-id}/`，按 `context`、`analysis`、
`design`、`plans`、`delivery`、`quality`、`workflow` 分类。禁止把活动制品
写到 `docs/artifacts/` 根目录，也禁止修改既有 `archive/` 内容。

专项报告按门禁阶段写入 `quality/gates/{gate-id}/`。首次为 `Check 001`，
复审在原文件追加后续 Check，引用原问题 ID 并标记 `RESOLVED`、
`STILL_OPEN` 或 `REGRESSED`。最后一个完整 Check 是当前有效结论。

所有实现变更必跑静态分析、逻辑正确性、可维护性和测试充分性审查；安全、
数据并发、可排查性及跨制品一致性由 `workflow/review-routing.md` 按风险触发。
最终结论只允许 `PASS`、`FAIL`、`HUMAN_REQUIRED`。

## 修改规则

新增或调整 Agent、Skill、Rule 时必须加载 `harness-resource-authoring`，按对应
模板确认领域归属、frontmatter、引用和资源数量。Rule 必须使用“适用范围、
强制规则、验证清单”结构，禁止新增“补充规则”兜底章节。

重复纠正先写入 `{artifact_root}/workflow/memory-change.md`，只有状态为
`APPROVED` 且包含用户批准记录时，`memory-consolidator` 才能写入目标 Rule 的
正确语义章节。增加或调整资源后必须执行资源校验和 Rule 交叉引用检查，不得
恢复旧 Agent 名、旧制品根路径或旧 Workflow Schema。
