# 请求意图路由

- 任务 ID：{task-id}
- 路由时间：{timestamp}
- 输入类型：{ONES_URL_ONLY|ISSUE_KEY_ONLY|TEXT_AND_ONES|USER_DESCRIPTION}
- 用户原始动作词：{none-or-verbatim-keywords}
- requested_mode：{investigation|fix}
- 代码修改授权：{AUTHORIZED|NOT_AUTHORIZED}
- 路由置信度：{HIGH|MEDIUM|LOW}

## 路由依据

{why-this-mode-was-selected}

## 默认规则

- 只有 ONES 链接或 Issue Key：`investigation`。
- “排查、分析、定位、查看”：`investigation`。
- 只有明确表达“修复、修改代码、实施修复”等意图：`fix`。
- `investigation` 允许获取 Issue、查询只读日志/数据库和分析代码，但禁止修改代码、
  测试、配置、Issue 状态和 Git。

## 歧义与升级

{none-or-conflicting-intent-and-human-question}
