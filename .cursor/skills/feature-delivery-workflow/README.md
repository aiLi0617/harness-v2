# feature-delivery-workflow 使用说明

> 功能交付的总指挥技能，编排从 PRD 到交付完成的端到端流程，调度各阶段子代理、管理制品传递与审查点。Agent 执行细节以 [`SKILL.md`](./SKILL.md) 为准。

## 这个 Skill 是做什么的

作为 feature-delivery 工作流的编排者，串联 9 个阶段（外加可选 PRD 导入与多个审查/人工确认点），负责：工作流初始化（加载调试日志、资源冲突检测、读取决策记录）、每阶段 before/after 日志、制品传递校验、审查闭环回退与异常处理。

- 主调度日志：`docs/artifacts/harness-debug.md`
- 配套编排定义：`workflows/feature-delivery.yaml`

## 适用场景

- 用户明确要"做一个新功能"或启动 feature-delivery 工作流
- 需要从 PRD 到完整实现的端到端交付

## 流程总览

```
[可选: 云文档导入] → ① PRD拆分 → ② 头脑风暴 → ③ 概要设计 → [一致性审查] → [HLD→飞书→人工确认]
  → ④ DDL / API 设计 → ⑤ 详细设计 → [一致性审查] → [LLD→飞书→人工确认]
  → ⑥ 实现计划 → ⑦ 编码 → [规格审查] → [质量审查] → [通用审查]
  → ⑧ 验证 → ⑨ 收尾归档
```

## 各阶段调度的资源

| 阶段 | 调度的代理 / 技能 | 产出制品 |
|------|------------------|----------|
| ① PRD 拆分 | `prd-splitter` | `feature-list.md` |
| ② 头脑风暴 | `brainstorming` | `brainstorm-result.md` |
| ③ 概要设计 | `architect-hld` | `hld.md` |
| ④ DDL / API | `db-ddl` / `api-contract` | `ddl.md` / `api-contract.md` |
| ⑤ 详细设计 | `lld-author` | `lld.md` |
| ⑥ 实现计划 | `impl-planner` + `writing-plans` | `impl-plan.md` |
| ⑦ 编码 | `implementer` + `codegen-guard` | 源代码 |
| 审查链 | `spec-reviewer` → `code-quality-reviewer` → `code-reviewer` | 审查报告 |
| ⑧ 验证 | `done-verify` | `verification-report.md` |
| ⑨ 收尾 | 归档到 `archive/{date}-{task}/` | — |

## 关键约束

- 每阶段开始前确认上游制品存在，缺失则停止并报告
- 审查闭环不通过回退对应代理，最多 5 轮，超限标记人工介入
- 用户决策影响已有制品时，回退到受影响的最早阶段重新执行

## 相关资源

| 资源 | 关系 |
|------|------|
| [`workflows/feature-delivery.yaml`](../../workflows/feature-delivery.yaml) | 工作流编排定义 |
| `harness-debug-logger` | 全程记录调度轨迹 |
| `hld-to-feishu` / `lld-to-feishu` | 设计发布与人工确认 |
