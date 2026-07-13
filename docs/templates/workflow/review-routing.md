# 质量审查路由

- 任务 ID：{task-id}
- 路由时间：{timestamp}
- 变更清单：`delivery/change-manifest.md`
- 路由版本：{change-version-or-commit}

| Reviewer | 必跑/条件 | 路由状态 | 触发或不触发证据 | 输出文件 |
|---|---|---|---|---|
| static-analysis-reviewer | 必跑 | TRIGGERED | 所有代码变更 | quality/gates/implementation/static-analysis.md |
| logic-correctness-reviewer | 必跑 | TRIGGERED | 所有代码变更 | quality/gates/implementation/logic-correctness.md |
| maintainability-reviewer | 必跑 | TRIGGERED | 所有代码变更 | quality/gates/implementation/maintainability.md |
| test-adequacy-reviewer | 必跑 | TRIGGERED | 所有代码变更 | quality/gates/implementation/test-adequacy.md |
| security-reviewer | 条件 | {TRIGGERED|NOT_TRIGGERED} | {api-auth-input-dependency-evidence} | quality/gates/implementation/security.md |
| data-concurrency-reviewer | 条件 | {TRIGGERED|NOT_TRIGGERED} | {db-transaction-cache-mq-job-evidence} | quality/gates/implementation/data-concurrency.md |
| diagnosability-reviewer | 条件 | {TRIGGERED|NOT_TRIGGERED} | {log-exception-rpc-job-mq-evidence} | quality/gates/implementation/diagnosability.md |
| consistency-reviewer | 条件 | {TRIGGERED|NOT_TRIGGERED} | {design-or-cross-artifact-evidence} | quality/gates/implementation/consistency.md |
| quality-gate-reviewer | 必跑、串行 | WAITING_FOR_JOIN | 汇总所有应到报告 | quality/gates/implementation/quality-gate.md |

## 路由结论

- 应到专项报告：{report-list}
- 并行组：`implementation-quality`
- fan-out 成员：{step-id-list}
- 最终裁决前置条件：所有应到报告存在且包含完整 Check
