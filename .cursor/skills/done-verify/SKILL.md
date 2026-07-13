---
name: done-verify
description: >-
  执行编译、测试、覆盖率、Lint、静态分析、依赖和范围验证，追加机械证据并形成 quality/verification-report.md。
  在代码变更进入专项质量审查前采集证据，以及质量门禁 PASS 后做最终验证时使用。
  不用于语义质量裁决、修改代码以掩盖失败或覆盖历史 Run。
---

# 完成交付验证

## 前置条件

- 获取 `artifact_root`、变更清单和当前代码 diff。
- 从项目配置与 Rule 解析可用命令和门禁阈值，不在本 Skill 重复阈值。

## 证据采集

依次执行适用于当前项目的检查，并追加到：

- `quality/evidence/implementation/compile-report.md`
- `quality/evidence/implementation/test-report.md`
- `quality/evidence/implementation/coverage-report.md`
- `quality/evidence/implementation/lint-report.md`
- `quality/evidence/implementation/static-analysis-report.md`
- `quality/evidence/implementation/dependency-scan-report.md`

每次执行追加 `Run NNN`，记录基线、命令、结果、摘要和完整报告位置；禁止覆盖历史 Run。无对应工具时记录 `NOT_AVAILABLE` 及原因，不伪造 PASS。

## 最终验证

1. 确认当前 gate 的 `quality-gate.md` 最后结论为 PASS。
2. 重新执行受变更影响的机械检查。
3. 校验变更清单与 diff、任务范围和归档必需制品。
4. 追加 `{artifact_root}/quality/verification-report.md`，结论为 PASS 或 FAIL。
5. FAIL 时不得归档为完成。

## 关联 Rule

遵守 `compile-guard`、`test-guard`、`lint-guard`、`scope-guard`、`schema-guard` 和 `environment-boundary`。
