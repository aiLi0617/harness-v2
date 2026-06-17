# Harness 工程 - 文档索引

> 入口文档：先读 [AGENTS.md](../.cursor/AGENTS.md)，再按需查阅以下文档。

| 文档 | 说明 |
|------|------|
| [harness-guide.md](harness-guide.md) | Harness 工程概念与结构说明 |
| [harness-plan.md](harness-plan.md) | 完整设计方案（三工作流渐进体系详细设计） |
| [review-checklist.md](review-checklist.md) | AI 产出人工审查清单 |
| [task-template.md](task-template.md) | 需求拆解模板 |
| [templates/](templates/) | 文档模板（调试日志 / 决策记录 / 审查清单 / 任务） |
| [senior-java-interview.md](senior-java-interview.md) | 资深 Java 工程师面试题（技术栈参考资料） |

## 快速开始

### 修复 Bug

告诉 AI："修复 [bug 描述]"，将自动启动 `bugfix` 工作流。

### 重构代码

告诉 AI："重构 [目标代码/模块]"，将自动启动 `refactoring` 工作流。

### 开发新功能

告诉 AI："实现 [PRD/需求描述]"，将自动启动 `feature-delivery` 工作流。

### 查看执行日志

工作流执行后，查看 `docs/artifacts/harness-debug.md` 了解完整轨迹。

### 查看历史制品

已完成任务的制品归档在 `docs/artifacts/archive/` 目录下。
