---
name: safe-refactoring
description: >-
  按 plans/refactoring-plan.md 逐步执行行为保持的安全重构，每步立即验证并在失败时停止。
  在 implementer 执行 refactoring Workflow 时使用。
  不用于功能开发、未建立行为基线或一次执行多种不可分离重构。
---

# 安全重构

## 前置条件

- 读取 `plans/refactoring-plan.md`、行为基线和相关测试。
- 确认当前步骤范围及验证命令。

## 操作步骤

1. 每次只执行计划中的一个重构步骤。
2. 新建源文件前调用 `codegen-guard`。
3. 保持公共接口、业务行为、数据语义和异常契约不变。
4. 完成一步立即运行该步验证和相关回归。
5. 验证失败时停止，不叠加下一步；定位是实现错误还是计划错误。
6. 更新 `delivery/change-manifest.md`，记录已完成步骤和证据。

## 失败与降级

- 发现功能变化时停止并回退 `refactoring-planner` 或人工检查点。
- 行为基线不充分时先补保护性测试。

## 关联 Rule

遵守 `change-implementation`、`scope-guard`、`test-guard`、`codegen-guard` 和 `human-checkpoint`。
