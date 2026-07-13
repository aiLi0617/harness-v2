# 数据库设计（DDL）

## 元数据

- 任务 ID：{task-id}
- 数据库/版本：{database-version}
- 设计时间：{timestamp}
- 状态：{DRAFT|APPROVED}

## 访问模式与数据规模

{reads-writes-cardinality-growth-hotspots-and-retention}

## Schema 设计

### {table-name}

| 字段 | 类型 | 空值/默认 | 约束 | 语义 |
|---|---|---|---|---|
| {column} | {type} | {nullable-default} | {constraint} | {meaning} |

### 索引与约束

| 名称 | 列/顺序 | 类型 | 对应查询/不变量 | 写入成本 |
|---|---|---|---|---|
| {index} | {columns} | {type} | {purpose} | {cost} |

## DDL 草案

```sql
{forward-ddl}
```

## 迁移步骤

1. {compatible-schema-change}
2. {backfill-and-validation}
3. {read-write-switch}
4. {cleanup}

## 一致性与并发

{transaction-lock-idempotency-tenant-cache-mq-impact}

## 回滚与风险

{rollback-lock-time-window-data-repair-and-monitoring}
