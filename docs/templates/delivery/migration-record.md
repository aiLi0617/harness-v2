# 数据迁移记录

## Migration {NNN}

- 任务 ID：{task-id}
- 环境：{environment}
- 计划引用：{ddl-or-rollout-plan}；脚本路径：`design/sql/` 或 `delivery/sql/` 下实际文件名
- 执行时间：{start-end}
- 执行者：{actor}
- 变更版本：{version}

## 执行记录

| 步骤 | 命令/任务 | 结果 | 影响行数/对象 | 耗时 |
|---|---|---|---|---|
| {N} | {action-reference} | {result} | {count} | {duration} |

## 校验

{row-count-checksum-business-sampling-and-errors}

## 回滚/补偿

{not-needed-or-actions-and-result}

## 结论

{SUCCESS|FAILED|PARTIAL|HUMAN_REQUIRED}：{summary}
