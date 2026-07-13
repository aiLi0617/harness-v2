# Workflow 状态

- 任务 ID：{task-id}
- Workflow：{bugfix|refactoring|feature-delivery}
- Schema 版本：2
- artifact_root：`docs/artifacts/work/{task-id}`
- 当前步骤：{step-id}
- 状态：{PENDING|RUNNING|PASSED|FAILED|HUMAN_REQUIRED|COMPLETED}
- 最后更新时间：{timestamp}

## 已完成步骤

| Step | 结果 | 输出制品 | 完成时间 |
|---|---|---|---|
| {step-id} | {PASS-SKIP} | {artifact-links} | {timestamp} |

## 当前阻塞或恢复上下文

- 原因：{none-or-reason}
- 已确认决策：{decision-links}
- 可恢复输入：{artifact-links}
- 重试次数：{count}

## 下一步

- Step：{step-id-or-human-checkpoint}
- 所需输入：{required-artifacts}
