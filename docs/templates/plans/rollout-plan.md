# 发布计划

## 元数据

- 任务 ID：{task-id}
- 版本/提交：{release-version-and-commit}
- 目标环境：{environment}
- 计划窗口：{time-window}

## 前置条件

- [ ] {artifact-test-approval-capacity-or-backup}

## 发布步骤

| 顺序 | 操作 | 责任方 | 验证 | 失败处理 |
|---|---|---|---|---|
| {N} | {action} | {owner} | {check} | {fallback} |

## 灰度与观测

{traffic-stage-metrics-logs-alerts-and-observation-duration}

## 回滚条件与步骤

- 触发条件：{thresholds}
- 回滚步骤：{steps}
- 数据兼容：{data-rollback-or-forward-fix}

## 发布后验证

- [ ] {business-and-technical-check}
