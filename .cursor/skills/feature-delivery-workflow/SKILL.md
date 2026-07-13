---
name: feature-delivery-workflow
description: >-
  解释并恢复 feature-delivery Workflow，处理灵活入口、缺失制品、资源冲突和日志初始化。
  在用户从任意阶段启动或恢复功能交付流程时使用。
  不用于定义八阶段顺序、并行关系、审查链、Agent 清单或制品链；这些只读取 Workflow YAML。
---

# 功能交付 Workflow 辅助

## 灵活入口

1. 读取 `.cursor/workflows/feature-delivery.yaml` 及其 `phases`。
2. 根据用户目标选择起始 phase，不在本 Skill 维护阶段顺序副本。
3. 读取起始 phase 的 `entry_artifacts.required` 与 `optional`。
4. 必需制品齐全时从该 phase 开始；缺失时列出缺口并触发人工检查点。

## 中断恢复

1. 获取 `artifact_root` 并读取 `workflow/workflow-state.md`。
2. 验证最后完成步骤的 `exit_artifacts` 仍存在且完整。
3. 从 Workflow 的 `next.on_pass` 恢复；状态与制品冲突时停止，不猜测进度。

## 资源冲突检测

- 启动前确认 `artifact_root` 只属于当前 `task_id`。
- 检查必需 Agent、Skill、phase 文件和 Rule 引用存在。
- 检查同一制品只有一个当前阶段生产者。
- 冲突写入 `workflow/decision-log.md` 并停止。

## 日志初始化

- 创建任务目录需要的分类子目录。
- 初始化 `workflow/workflow-state.md`、`workflow/decision-log.md` 和 `workflow/harness-debug.md`。
- 使用 `harness-debug-logger` 记录入口、当前 phase 和缺失制品检查结果。

## 边界

不得在本 Skill 写入或复制八阶段 ASCII 图、阶段说明、并行配置、审查链、Agent 清单、制品链或 review loop。以上内容的唯一来源是 `feature-delivery.yaml` 与 `feature-delivery/phase-*.yaml`。
