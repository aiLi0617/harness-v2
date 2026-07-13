# LLD 一致性审查

## Check 001

- 时间：{timestamp}
- 制品版本：{artifact-version}
- Reviewer：consistency-reviewer
- 输入：`design/hld.md`、`design/lld.md`、按需 DDL/API
- 当前结论：{PASS|FAIL|HUMAN_REQUIRED}

## 追踪矩阵

| 上游条目 | LLD 章节/组件 | 状态 | 说明 |
|---|---|---|---|
| {source} | {target} | {COVERED|MISSING|CONFLICT} | {notes} |

## 问题

### {LLD-CON-NNN}: {标题}

- 严重级别：{BLOCKER|WARNING|ADVISORY}
- 状态：{OPEN|RESOLVED|STILL_OPEN|REGRESSED}
- 证据：{two-or-more-artifact-references}
- 问题说明：{description}
- 影响：{impact}
- 修复要求：{required-fix}
- 置信度：{HIGH|MEDIUM|LOW}
