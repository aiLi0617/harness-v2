---
name: tdd-bugfix
description: >-
  使用失败测试锁定已确认根因，再做最小修复并验证回归。
  在 implementer 消费 analysis/root-cause.md 执行 Bug 修复时使用。
  不用于根因未确认、无可验证行为或夹带重构和新功能的修改。
---

# TDD Bug 修复

## 前置条件

- 读取 `analysis/root-cause.md` 和存在时的 `plans/implementation-plan.md`。
- 明确修复前失败行为、修复后期望和回归范围。

## 操作步骤

1. 编写或选择能稳定复现根因的最小失败测试。
2. 运行测试，确认失败原因与根因一致；不一致则回退 `problem-analyst`。
3. 实施只针对根因的最小修复。
4. 运行目标测试、相关模块测试和必要回归。
5. 检查相同错误模式是否存在于本次影响范围内。
6. 更新 `{artifact_root}/delivery/change-manifest.md`，记录测试证据和未处理风险。

## 失败与降级

- 无法稳定复现时不得以偶然绿灯完成修复。
- 修复需要改变需求、API 或数据语义时触发人工检查点。

## 关联 Rule

遵守 `test-guard`、`compile-guard`、`scope-guard`、`change-implementation` 和 `human-checkpoint`。
