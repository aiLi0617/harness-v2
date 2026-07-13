# 文档索引

`docs/` 只保存现行架构说明、资源维护指南、制品模板和任务制品。
项目简介、安装方法、入口和 Agent 清单请优先阅读根目录
[`README.md`](../README.md)。

## 现行文档

| 文档 | 说明 |
|---|---|
| [`architecture.md`](architecture.md) | 四层领域模型、Workflow、质量协议和制品生命周期 |
| [`resource-placement-guide.md`](resource-placement-guide.md) | 判断内容应放 Agent、Skill、Workflow、Rule 或 docs 的规则 |
| [`templates/README.md`](templates/README.md) | 全量活动制品、机械证据和质量门禁模板索引 |

## 制品

- 活动任务：`artifacts/work/{task-id}/`
- 历史归档：`artifacts/archive/{date}-{task-id}/`
- 重构前快照：`artifacts/archive/2026-07-13-pre-agent-skill-refactor/`

历史归档只读，不参与现行名称和目录结构校验。
