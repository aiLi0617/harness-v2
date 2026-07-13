# 发布执行记录

## Rollout {NNN}

- 任务 ID：{task-id}
- 环境：{environment}
- 版本/提交：{version-and-commit}
- 执行时间：{start-end}
- 执行者：{actor}

## 阶段记录

| 阶段 | 操作 | 验证结果 | 指标/日志 | 决策 |
|---|---|---|---|---|
| {stage} | {action} | {result} | {evidence} | {continue-rollback-pause} |

## 异常与处理

{none-or-incidents}

## 最终状态

- 状态：{SUCCESS|ROLLED_BACK|PARTIAL|HUMAN_REQUIRED}
- 当前流量/版本：{state}
- 后续观察：{owner-duration-and-thresholds}
