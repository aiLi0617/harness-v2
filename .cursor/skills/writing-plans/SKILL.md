---
name: writing-plans
description: >-
  将 LLD 或根因分析拆成有依赖、文件范围、完成条件和验证方式的可执行实现计划。
  在 implementation-planner 产出 plans/implementation-plan.md 时使用。
  不用于编写代码、重新设计需求或把关键决定推迟到实现阶段。
---

# 编写实现计划

## 前置条件

- 获取 `artifact_root`。
- 功能实现读取 `design/lld.md`；复杂 Bug 读取 `analysis/root-cause.md`。
- 按需读取 HLD、DDL、API、影响分析和决策记录。

## 操作步骤

1. 提取必须交付的行为、文件类型、外部契约和验收条件。
2. 搜索实际模块和测试位置，禁止编造路径。
3. 按可独立验证的最小单元拆分任务。
4. 为每个任务声明文件范围、依赖、是否可并行、完成标准和验证命令。
5. 将数据库、API、配置和兼容性变更放在正确依赖顺序。
6. 检查所有上游要求均被某个任务覆盖，且无范围外工作。
7. 写入 `{artifact_root}/plans/implementation-plan.md`。

## 计划模板

```markdown
# 实现计划
## 输入制品与范围
## 任务依赖图
## 任务清单
### 任务 N
- 目标：
- 文件范围：
- 依赖：
- 可并行：
- 完成标准：
- 验证方式：
## 风险与人工检查点
```

## 失败与降级

- 找不到真实模块或路径时记录待确认项，不生成猜测路径。
- 上游设计不足以决定实现时停止并回退对应设计 Agent。

## 关联 Rule

遵守 `task-decomposition`、`scope-guard`、`stage-contracts` 和 `human-checkpoint`。
