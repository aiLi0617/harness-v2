# 根因分析

## 元数据

- 任务 ID：{task-id}
- 问题来源：`context/issue-context.md`
- 分析时间：{timestamp}
- 结论置信度：{HIGH|MEDIUM|LOW}

## 现象与触发条件

{symptom-and-minimal-trigger}

## 根因结论

{precise-root-cause}

## 因果链

1. {cause-step}
2. {cause-step}
3. {observable-failure}

## 证据

| 证据 | 位置 | 支持的结论 |
|---|---|---|
| {code-log-test-git} | {file-line-or-artifact-section} | {claim} |

## 已排除假设

| 假设 | 排除证据 |
|---|---|
| {hypothesis} | {evidence} |

## 影响范围与修复方向

- 影响：{scope}
- 最小修复方向：{direction-not-implementation}
- 回归重点：{regression-risks}
- 仍缺证据：{none-or-list}
