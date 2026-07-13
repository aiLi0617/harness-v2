---
name: harness-resource-authoring
description: >-
  创建或更新 Harness Agent、Skill、Rule，并同步相关引用、资源数量与校验契约。
  当用户要求新增、重构、重命名或标准化 .cursor/agents、.cursor/skills、
  .cursor/rules 资源时使用。不用于创建 Workflow、修改业务代码或引入 Registry、
  alias、domain、tags 等 Cursor 不消费的发现元数据。
---

# Harness 资源编写

## 先判定资源类型

1. 只有具备可独立调度的 WHO + WHAT + CONTRACT 时才创建 Agent。
2. 只有复杂、可复用、可选加载的 HOW 才创建 Skill。
3. 只有应在匹配任务中持续生效的约束才创建 Rule。
4. 涉及阶段顺序、条件、并行、回退或状态时停止，改由 Workflow 维护。
5. 创建前搜索同名和同义资源；能够扩展现有资源时禁止新增。

## 按类型读取模板

- Agent：完整读取 [agent-template.md](references/agent-template.md)。
- Skill：完整读取 [skill-template.md](references/skill-template.md)。
- Rule：完整读取 [rule-template.mdc](references/rule-template.mdc)。

只读取当前资源类型的模板；跨类型修改时再加载对应模板。

## 执行流程

1. 确认名称、职责边界、调用场景和预期消费者。
2. 搜索现有资源、Workflow、Rule、README 和 AGENTS 引用。
3. 按模板创建或更新最小内容，不复制其他层职责。
4. 同步所有直接引用、资源清单和校验中的预期数量。
5. Rule 新增领域时更新通用路由；项目 Rule 不进入通用分类表。
6. 运行 PowerShell 或 Shell 版本的资源校验与交叉引用检查。
7. 涉及 Workflow 引用时追加运行 Workflow 冒烟。

## 停止条件

- 新 Agent 与现有 Agent 职责重叠且无法形成独立交付契约。
- 新 Skill 只是简短岗位策略或为了与 Agent 成对。
- 新 Rule 与现有 Rule 同义，或无法确定通用/项目作用域。
- 修改会改变 Workflow 用户入口、业务代码或历史归档。
- Rule 候选没有人工批准却要求直接固化。

## 完成检查

- 名称、frontmatter、文件或目录名一致。
- 内容只包含所属资源层的职责。
- 引用、计数、文档和模板已同步。
- `.cursor/scripts/` 仍只包含 `.ps1` 与 `.sh`。
- 资源校验、Rule 交叉引用和相关冒烟全部通过。
