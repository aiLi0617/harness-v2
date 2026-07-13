# 生产可排查性审查

## Check 001

- 时间：{timestamp}
- Reviewer：diagnosability-reviewer
- 代码版本：{version}
- 故障场景范围：{scope}
- 当前结论：{PASS|FAIL|HUMAN_REQUIRED}

## 发现

### {DIA-NNN}: {标题}

- 严重级别：{BLOCKER|WARNING|ADVISORY}
- 状态：{OPEN|RESOLVED|STILL_OPEN|REGRESSED}
- 证据：{failure-path-file-line-and-missing-signal}
- 问题说明：{detection-correlation-localization-gap}
- 影响：{operational-impact}
- 修复要求：{minimum-log-metric-trace-alert-change}
- 置信度：{HIGH|MEDIUM|LOW}
