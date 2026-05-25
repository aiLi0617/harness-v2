# 决策日志

## [2026-05-23] Java 开发手册（黄山版）规则导入

**背景**: 将《Java 开发手册（黄山版）》全量导入 `.cursor/rules/memory/`，与现有项目规范合并；冲突项由用户决策。

**决策汇总**:

| 冲突项 | 决策 | 落地方式 |
|--------|------|----------|
| 数据库布尔字段命名 | **不使用 `is_` 前缀**，`bit(1)`，如 `deleted`/`enabled`（覆盖此前对齐手册 `is_xxx` 的决策） | `database-conventions.mdc`、`orm-mybatis-conventions.mdc` |
| 单方法行数上限 | 改为 80 行（对齐手册【推荐】） | `code-style-format.mdc`、`method-design.mdc` |
| private 方法注释 | 对齐手册：private 不要求 Javadoc，复杂逻辑用行注释 | `comment-conventions.mdc` 移除 private 完整 Javadoc 强制要求 |
| 空值判断写法 | 保留 `Objects.isNull/isNotNull`，禁止 `== null` | `null-safety.mdc` 不变 |
| 表必备字段 | 保留 6 字段审计/逻辑删除体系 | `database-conventions.mdc` 标注为项目扩展 |
| 日志 debug 守卫 | 保留 `isDebugEnabled()` 守卫要求 | `logging.mdc` 删除与之矛盾的补充规则 |

**影响**: 新建 `design-conventions.mdc`、`error-codes.mdc`；各 memory 规则文件补充手册缺口；同步 `coding-standards-loader`、`correction-detection`、`memory-consolidator` 分类表。
