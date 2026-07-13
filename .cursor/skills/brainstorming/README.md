# brainstorming 使用说明

> 结构化探索需求的多种实现方案，避免拿到需求就直接写代码。Agent 执行细节以 [`SKILL.md`](./SKILL.md) 为准。

## 这个 Skill 是做什么的

在动手设计/编码之前，先把一个需求展开为 2–3 个候选技术方案，建立对比矩阵，给出带理由的推荐方案，并标注需要用户确认的决策点。本技能只做**分析与讨论**，不产出设计文档或代码。

- 主要产出：**`{artifact_root}/design/brainstorm-result.md`**
- 上游：`requirements-analyst` 产出的 `feature-list.md`
- 下游：`solution-architect`（概要设计）

## 适用场景

- 拿到新 PRD 或新需求，尚未确定技术方案
- 功能交付工作流的概要设计阶段之前
- 用户明确要求"讨论一下方案"

## 前置条件

- `{artifact_root}/analysis/feature-list.md` 已存在；不存在则停止并报告缺失

## 流程概览

```
feature-list.md
      ↓
1. 梳理边界   → 提取功能/技术/非功能/时间/集成约束
      ↓
2. 列举方案   → 至少 2–3 种，各含核心思路与关键设计
      ↓
3. 对比优劣   → 复杂度/性能/可维护性/工期/风险/兼容性矩阵
      ↓
4. 输出推荐   → 写入 brainstorm-result.md，列出待确认事项
```

## 产出物

| 文件 | 说明 |
|------|------|
| `{artifact_root}/design/brainstorm-result.md` | 约束清单、方案列表、对比矩阵、推荐方案、待确认事项 |

## 关键约束

- 必须列出至少 2 种方案，不能只给一种
- 推荐方案必须基于对比分析，不能凭直觉
- 关键决策点必须写入"待确认事项"，交人工确认
- 输出路径固定为 `{artifact_root}/design/brainstorm-result.md`

## 相关资源

| 资源 | 关系 |
|------|------|
| [`writing-plans`](../writing-plans/SKILL.md) | 设计落地后的实现计划编排 |
| `feature-delivery-workflow` | 工作流阶段②调度本技能 |
