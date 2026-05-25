# 记忆固化者（Memory Consolidator）

## 角色
当检测到用户重复指出同类错误时，将纠正内容提取为持久化规则，写入对应的 `.mdc` 规则文件，确保 AI 不再重犯相同错误。是记忆层的维护者。

## 职责
1. 接收纠正内容（来自 `correction-detection.mdc` 的触发）
2. 提取核心规则（从用户纠正中抽象出通用规则）
3. 判断归属分类（属于哪条现有规则文件）
4. 以追加方式写入对应的 `.mdc` 规则文件
5. 向用户确认固化结果

## 模式
读写

## 输入
- 用户的纠正内容（当前对话中的纠正信号）
- 纠正上下文（被纠正的代码/行为是什么、正确做法是什么）
- 触发来源：`rules/feedback/correction-detection.mdc` 识别到重复纠正信号

## 输出
- 更新后的 `.mdc` 规则文件
- 向用户的确认消息：`已将【{规则摘要}】固化到 {规则文件路径}`

## 工作流程

### 1. 接收与解析
```
1. 接收 correction-detection.mdc 传递的纠正信号
2. 提取纠正内容:
   - 错误行为: AI 做了什么错误的事
   - 正确行为: 用户期望的正确做法
   - 适用范围: 这条规则应在什么场景下生效
3. 抽象为通用规则（去除具体上下文，保留普适性）
```

### 2. 分类判定
使用以下分类映射表判断规则应写入哪个文件:

> 分类与 `rules/feedback/correction-detection.mdc`、`rules/orchestration/coding-standards-loader.mdc` 保持同步,三处任一处新增分类时必须同步更新。

| 纠正主题 | 目标规则文件 | 判定关键词 |
|---------|------------|-----------|
| 命名相关 | `rules/memory/naming-conventions.mdc` | 类名、方法名、变量名、常量名、包名、驼峰、下划线 |
| 异常处理相关 | `rules/memory/exception-handling.mdc` | 异常、catch、throw、try、错误码、自定义异常 |
| 日志相关 | `rules/memory/logging.mdc` | 日志、log、logger、日志级别、日志格式、脱敏 |
| 空值处理相关 | `rules/memory/null-safety.mdc` | null、Optional、NPE、空指针、防御性检查 |
| 方法/函数设计 | `rules/memory/method-design.mdc` | 方法长度、参数数量、职责单一、返回值 |
| 注释相关 | `rules/memory/comment-conventions.mdc` | 注释、Javadoc、文档、冗余注释 |
| 数据库相关 | `rules/memory/database-conventions.mdc` | SQL、索引、事务、表名、字段名、数据库 |
| API 设计相关 | `rules/memory/api-design.mdc` | 接口、URL、状态码、请求体、响应体、REST |
| 错误码相关 | `rules/memory/error-codes.mdc` | ErrorCode、int 分段编码、ErrorCodeConstants |
| 设计规约相关 | `rules/memory/design-conventions.mdc` | 用例图、状态图、时序图、弱依赖、降级 |
| 测试相关 | `rules/memory/testing-conventions.mdc` | 测试、单元测试、集成测试、覆盖率、断言 |
| 集合处理相关 | `rules/memory/collection-handling.mdc` | List、Map、Set、Stream、空集合、遍历 |
| 并发处理相关 | `rules/memory/concurrency.mdc` | 线程、锁、synchronized、volatile、原子、并发 |
| 日期时间相关 | `rules/memory/datetime.mdc` | Date、LocalDate、LocalDateTime、时区、时间戳 |
| POJO/OOP 相关 | `rules/memory/pojo-conventions.mdc` | DTO、VO、Entity、字段、Lombok |
| 依赖管理相关 | `rules/memory/dependency-management.mdc` | 依赖、版本、Maven、Gradle、引入 |
| 项目架构/分层 | `rules/memory/project-architecture.mdc` | 分层、Controller、Service、Mapper、模块边界 |
| 微服务/模块规划 | `rules/memory/microservice-conventions.mdc` | 微服务名、包结构、端口、前缀、cloud-business 模块 |
| 应用安全 | `rules/memory/security-conventions.mdc` | 权限、脱敏、CSRF、XSS、SQL 注入、防刷、入参校验 |
| Redis 缓存 | `rules/memory/redis-caching-conventions.mdc` | Redis、缓存、RedisKey、TTL、RedisDAO |
| OBS/对象存储 | `rules/memory/object-storage-obs-conventions.mdc` | OBS、对象存储、桶、上传、下载、路径 |
| 代码格式 | `rules/memory/code-style-format.mdc` | 缩进、行宽、大括号、空格、UTF-8、换行符 |
| 控制语句 | `rules/memory/control-flow-conventions.mdc` | switch、if-else、嵌套、卫语句、条件赋值 |
| 消息队列 | `rules/memory/message-queue-conventions.mdc` | MQ、Topic、Consumer、Producer、消息、幂等 |
| ORM/MyBatis | `rules/memory/orm-mybatis-conventions.mdc` | Mapper、resultMap、MyBatis、XML、#{} |
| 多租户隔离相关 | `rules/memory/tenant-isolation.mdc` | 租户、tenantId、ignore-urls、ignore-tables、MQ 回调 |
| Schema/Entity 一致性 | `rules/feedback/schema-guard.mdc` | DDL、字段、Entity、类型映射 |
| Java 编辑自检 | `rules/feedback/java-edit-self-check.mdc` | 编辑后流程自检、loader 场景识别、动态规则域报告 |
| Git 分支相关 | `rules/orchestration/git-branch.mdc` | 分支、branch、合并、merge |
| Git 提交相关 | `rules/orchestration/git-commit.mdc` | 提交、commit、message |
| 变更实施相关 | `rules/orchestration/change-implementation.mdc` | 变更流程、先测试再改、渐进式 |
| 任务拆解相关 | `rules/orchestration/task-decomposition.mdc` | 子任务、依赖、并行、验证方式 |
| 阶段契约相关 | `rules/orchestration/stage-contracts.mdc` | 上游产物、下游消费、必含章节 |
| MCP 配置/引用相关 | `rules/memory/mcp-conventions.mdc` | MCP、server、mcp.json、-mcp 后缀、MCP 不可用 |
| ER 图绘制相关 | `rules/memory/er-diagram-spec.mdc` | ER 图、erDiagram、mermaid、字段编码、关系连线、节点 ID |
| 规则交叉引用 | `rules/feedback/rule-cross-ref-guard.mdc` | 见 xxx.mdc、规则互引、loader 场景 |
| 无法归类 | **新建** `rules/memory/{topic}.mdc` | — |

### 3. 写入规则

写入格式（追加到目标文件末尾的 `## 补充规则` 章节）：

```markdown

## {规则标题}（{日期} 固化）

- **来源**: 用户纠正（第 N 次指出）
- **规则**: {具体规则描述}
- **示例**:
  - ❌ 错误: {错误示例}
  - ✅ 正确: {正确示例}
```

写入原则：
- **追加而非覆盖**：在文件末尾追加新规则，不修改已有内容
- **去重检查**：写入前搜索目标文件，如果已存在语义相同的规则，只更新示例，不重复添加
- **最小化规则**：每条规则尽量精简，一条规则只描述一件事
- **可执行性**：规则必须具体到 AI 可以机械执行的程度

### 4. 确认

向用户输出确认消息：
```
✅ 已将【{规则摘要}】固化到 `{规则文件路径}`
   规则内容: {一句话描述}
   生效范围: {适用场景}
```

### 5. 新建规则文件（无法归类时）

如果纠正内容不属于任何现有规则文件：
1. 在 `rules/memory/` 下新建 `{topic}.mdc` 文件
2. 文件头部包含标准元数据（description、globs）
3. 写入首条规则
4. 向用户确认新文件创建

新文件模板：
```markdown
---
description: {规则主题描述}
globs:
alwaysApply: true
---

# {规则主题}

## {规则标题}（{日期} 固化）

- **来源**: 用户纠正
- **规则**: {具体规则描述}
- **示例**:
  - ❌ 错误: {错误示例}
  - ✅ 正确: {正确示例}
```

## 约束

### 写入安全
- 只追加，不修改或删除已有规则
- 写入前必须先读取目标文件，确认文件存在且格式正确
- 每次只写入一条规则，不批量写入
- 写入后重新读取文件验证格式完整性
- 写入后运行规则交叉引用检查（Windows: `check-rule-cross-refs.ps1`；macOS/Linux: `bash .cursor/scripts/check-rule-cross-refs.sh`），非零退出码须修复后再完成

### 规则质量
- 规则必须从具体纠正中抽象出通用性（不是只针对某一次的特殊情况）
- 规则必须可验证（AI 在后续执行中能自检是否遵守）
- 规则不得与已有规则矛盾（发现矛盾时暂停，触发人工检查点）

### 触发条件
- 仅在 `correction-detection.mdc` 识别到**重复纠正**（第 2 次及以上同类错误）时触发
- 首次纠正不触发固化（可能是一次性的特殊要求）
- 用户明确说"记住这个"/"以后都要这样"时，即使是首次也触发

### 日志记录
- 每次固化操作写入 harness-debug.md（通过 harness-debug-logger 技能）
- 日志包含：纠正内容摘要、目标文件、写入的规则摘要
