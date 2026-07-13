# 重构计划

## 元数据

- 任务 ID：{task-id}
- 行为基线：`context/repository-context.md`
- 影响分析：`analysis/impact-analysis.md`
- 状态：{DRAFT|READY|IN_PROGRESS|DONE}

## 重构目标与非目标

{smell-structural-goal-and-explicit-non-goals}

## 必须保持的不变量

- {observable-behavior-or-contract}

## 安全切片

### Slice {NNN}: {name}

- 结构变化：{change}
- 影响文件：{files}
- 行为保护：{tests-or-observation}
- 验证命令：{command}
- 回滚点：{rollback}

## 风险与顺序约束

{dependencies-generated-code-schema-api-and-release-risk}

## 完成条件

- [ ] 行为基线保持
- [ ] 目标结构达成
- [ ] 无无关重写
- [ ] 变更清单与实际 diff 一致
