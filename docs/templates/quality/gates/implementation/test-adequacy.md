# 测试充分性审查

## Check 001

- 时间：{timestamp}
- Reviewer：test-adequacy-reviewer
- 代码版本：{version}
- 测试报告版本：{run}
- 当前结论：{PASS|FAIL|HUMAN_REQUIRED}

## 风险到测试追踪

| 需求/风险 | 测试 | 关键断言 | 状态 |
|---|---|---|---|
| {risk} | {test} | {assertion} | {COVERED|WEAK|MISSING} |

## 发现

### {TST-NNN}: {标题}

- 严重级别：{BLOCKER|WARNING|ADVISORY}
- 状态：{OPEN|RESOLVED|STILL_OPEN|REGRESSED}
- 证据：{risk-test-file-line-report}
- 问题说明：{missing-or-ineffective-protection}
- 影响：{regression-risk}
- 修复要求：{scenario-and-required-assertion}
- 置信度：{HIGH|MEDIUM|LOW}
