# 制品模板目录

本目录镜像 `docs/artifacts/work/{task-id}/` 的现行制品结构。新任务初始化时按
Workflow 实际需要复制模板，不要一次性生成空白制品。

| 分类 | 模板 | 主要生产者 |
|---|---|---|
| `context/` | PRD、Issue、日志证据、仓库上下文 | 用户、获取型 Agent、主会话 |
| `analysis/` | 功能清单、根因、影响、日志调查 | 分析型 Agent |
| `design/` | Brainstorm、HLD、DDL、API、LLD；可执行脚本模板在 `design/sql/` | 设计型 Agent |
| `plans/` | 实现、重构、测试、发布计划 | 规划型 Agent |
| `delivery/` | 变更、发布、迁移、上线记录；无设计阶段订正脚本模板在 `delivery/sql/` | Implementer、发布阶段 |
| `quality/evidence/` | 编译、测试、覆盖率、Lint、扫描证据 | `done-verify` |
| `quality/gates/` | 专项审查和最终门禁 | 质量委员会 |
| `workflow/` | 意图、状态、决策、调试、审查路由、Rule 固化候选 | Workflow 主会话 |
| `tooling/` | Maven 测试覆盖率配置示例 | 工程配置维护者 |

通用约定：

- `{task-id}`、`{timestamp}`、`{producer}` 等花括号内容必须替换。
- 路径始终相对 `artifact_root=docs/artifacts/work/{task-id}`。
- 不适用的可选章节写明“不适用 + 理由”，不要伪造数据。
- 质量报告在同一文件追加 `Check NNN`，机械证据追加 `Run NNN`。
- 旧 Check/Run 禁止修改；文件最后一个完整记录代表当前状态。
