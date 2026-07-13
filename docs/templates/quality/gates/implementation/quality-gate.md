# 实现质量门禁

## Check 001

- 时间：{timestamp}
- Reviewer：quality-gate-reviewer
- 代码版本：{version}
- 路由版本：{review-routing-version}
- 最终结论：{PASS|FAIL|HUMAN_REQUIRED}

## 报告完整性

| Reviewer | 应到 | 最新 Check | 报告结论 | 状态 |
|---|---|---|---|---|
| {reviewer} | {yes-no} | {NNN-or-missing} | {result} | {received-missing-not-triggered} |

## 未解决问题

| 问题 ID | 来源 | 级别 | 状态 | 裁决 |
|---|---|---|---|---|
| {id} | {report} | {severity} | {status} | {decision} |

## 重复项与冲突裁决

{deduplication-conflicts-evidence-priority-and-reasoning}

## 下一步

- 修复目标：{none-or-workflow-step}
- 必须重采集的 Run：{none-or-list}
- 必须重跑的 Reviewer：{none-or-list}
- 人工决策问题：{none-or-list}
