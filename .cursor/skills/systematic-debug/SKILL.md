---
name: systematic-debug
description: >-
  使用证据驱动的假设验证定位 Bug、测试失败、构建失败和线上异常根因。
  在 problem-analyst 需要追踪调用链、比较竞争假设并产出 analysis/root-cause.md 时使用。
  不用于直接修改代码、凭相关性宣称根因或替代质量审查。
---

# 系统化根因分析

## 前置条件

- 获取 `artifact_root` 和问题描述或 `context/issue-context.md`。
- 按需读取 `context/log-evidence.md`、`analysis/log-investigation.md`、复现输出和最近变更。
- 输入不足时先记录缺口，不猜测 traceId、环境、时间和业务条件。

## 操作步骤

1. 复述可观察现象、影响和成功复现条件。
2. 从堆栈、日志或失败断言定位最窄代码范围，绘制入口到异常点的调用链。
3. 列出至少两个可区分的竞争假设；只有证据已唯一指向根因时才允许单假设。
4. 按验证成本和信息增益排序，逐个设计只读验证。
5. 执行验证并记录“假设—方法—证据—结论”，不得只记录最终答案。
6. 使用 Git 历史、数据流和同模式搜索确认触发条件及影响范围。
7. 排除主要竞争假设，形成完整因果链和最小修复方向。
8. 写入 `{artifact_root}/analysis/root-cause.md`；跨模块或迁移影响写入 `analysis/impact-analysis.md`。

## 根因报告模板

```markdown
# 根因分析

## 问题与影响
## 复现结果
## 调用链与数据流
## 假设验证记录
| 假设 | 验证方法 | 证据 | 结论 |
|---|---|---|---|
## 已确认根因
## 触发条件
## 影响范围
## 修复方向与回归建议
## 未解决风险
```

## 失败与降级

- 无法复现时记录环境差异，继续使用静态和历史证据，但降低结论置信度。
- 证据无法区分假设时停止，列出最小补充证据并触发人工检查点。
- 外部系统不可用时保留查询条件，不伪造结果。

## 关联 Rule

遵守 `execution-boundary`、`environment-boundary`、`human-checkpoint` 和当前场景由 `rules-loader` 激活的规则。
