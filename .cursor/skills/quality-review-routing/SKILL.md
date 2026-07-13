---
name: quality-review-routing
description: >-
  根据 change-manifest、实际 diff、机械证据和已有设计制品生成 workflow/review-routing.md。
  在 Bugfix、Refactoring 和 Feature delivery 的实现证据采集完成后、专项审查开始前使用。
  不用于执行专项审查、修改代码、替代最终质量裁决或决定 Workflow 阶段顺序。
---

# 质量审查路由

## 前置输入

- `{artifact_root}/delivery/change-manifest.md`
- 实际代码 diff 与变更文件列表
- `{artifact_root}/quality/evidence/implementation/` 中已生成的机械证据
- 可选的需求、HLD、DDL、API、LLD、实现/重构计划和影响分析

变更清单与实际 diff 不一致时停止，要求实现者先修正变更清单。

## 生成路由

1. 固定启用以下 Reviewer：
   - `static-analysis-reviewer`
   - `logic-correctness-reviewer`
   - `maintainability-reviewer`
   - `test-adequacy-reviewer`
2. 对每个条件 Reviewer 独立判断：
   - API、鉴权、权限、用户输入、敏感数据、依赖升级：`security-reviewer`
   - 数据库、事务、缓存、MQ、Job、异步、并发：`data-concurrency-reviewer`
   - 日志、异常、远程调用、Job、MQ、线上链路：`diagnosability-reviewer`
   - 存在设计制品或跨制品交付：`consistency-reviewer`
3. Feature delivery 实现阶段始终启用 `consistency-reviewer`。
4. 对启用和不启用的条件 Reviewer 都记录文件、制品章节或风险标签证据。
5. 将所有启用 Reviewer 对应的报告文件列为最终门禁应到报告。

## 输出契约

生成 `{artifact_root}/workflow/review-routing.md`，必须包含：

- 路由时间和对应代码/变更清单版本
- 每个 Reviewer 的必跑/条件属性
- `TRIGGERED`、`NOT_TRIGGERED` 状态
- 触发或不触发的具体证据
- 预期输出报告路径
- `implementation-quality` fan-out 成员清单
- 最终 Gate 的应到报告清单

使用 `docs/templates/workflow/review-routing.md` 的结构。信息不足时不得默认关闭
风险 Reviewer；标记 `HUMAN_REQUIRED` 并进入人工检查点。

## 边界

- 不读取 Reviewer 最终结论来反向修改路由。
- 不执行 Reviewer，不生成专项报告。
- 不以文件扩展名作为唯一风险证据。
- 不允许最终 Gate 在应到报告缺失时运行。
