# zfnjjs-harness-v2

> 一套围绕 Cursor IDE 的 AI 编码 Agent 工程化配置仓库。它通过 **Rules / Skills / Agents / Workflows / MCP** 五类资源,弥补 LLM 的固有缺陷(无状态、上下文受限、输出概率性),让 AI 在协助开发时**可靠、可追溯、可治理**。

## 一句话定位

`Agent = Model + Harness`。本仓库提供的就是那个 **Harness**——同一个模型,有了它,可以在固定工作流上稳定产出符合本项目编码规范、可被人工审计的代码与设计制品。

## 仓库结构

```
.cursor/
  AGENTS.md                ← 顶层代理指令(架构概述 + 三工作流总览)
  CLAUDE.md                ← LLM 通用行为准则(精简版)
  mcp/                     ← MCP 服务管理
    mcp-template.json        MCP 配置模板(不含密钥,复制为 .cursor/mcp.json 后填入)
  rules/                   ← 被动规则,自动加载(共 33 条)
    memory/   (17)          编码规范:命名/异常/日志/空值/方法/注释/集合/并发/日期/POJO/依赖/API/数据库/测试/项目架构/多租户隔离/MCP 规范
    orchestration/ (6)      工作流编排:Git 分支/Git 提交/变更实施/任务拆解/阶段契约/规则加载器
    feedback/ (8)           门禁守卫:编译/Lint/测试/变更范围/Schema/纠正检测/人工检查点/Java 编辑自检
    execution/ (2)          安全边界:操作红线/环境边界
  skills/                  ← 主动技能,按需调用(共 13 个)
    shared/   (4)           调试日志/完成验证/Git Worktree/代码生成守卫
    bugfix/   (2)           结构化调试/测试驱动修复
    refactoring/ (2)        重构规划/安全重构
    feature/  (5)           头脑风暴/编写计划/全流程编排/HLD→飞书/LLD→飞书
  agents/                  ← 子代理,工作流调度(共 15 个)
    shared/   (4)           实现者/代码审查者/记忆固化/一致性审查
    bugfix/   (2)           Bug 分析师/ONES+Loki 排查
    refactoring/ (2)        重构规划师/质量审查
    feature/  (7)           PRD 拆分/HLD/DDL/API/LLD/实现规划/规格审查
  workflows/               ← 工作流 YAML(共 3 个,渐进包含)
    bugfix.yaml              Bug 修复(最小集)
    refactoring.yaml         代码重构(在 Bug 修复基础上扩展)
    feature-delivery.yaml    PRD→交付(完整流水线)
docs/
  harness-guide.md         ← 入门指南(为什么 + 怎么用)
  harness-plan.md          ← 完整设计方案
  review-checklist.md      ← AI 产出的人工审查清单
  task-template.md         ← 需求拆解模板
  artifacts/               ← 子代理间的制品交接目录
    archive/                  历史制品归档
link-cursor-config.ps1     ← Windows: 将 .cursor/ 软链到目标业务项目
link-cursor-config.sh      ← macOS/Linux: 同上
```

## 三工作流(渐进包含)

| 工作流 | 入口 | 适用场景 |
|--------|------|---------|
| **Bug 修复** | `workflows/bugfix.yaml` | 已知 bug、异常报告、线上问题 |
| **代码重构** | `workflows/refactoring.yaml` | 消除坏味道、改善结构、提升可维护性(继承 Bug 修复) |
| **功能交付** | `workflows/feature-delivery.yaml` | 新功能开发、需求迭代、模块新建(继承重构,含云文档导入与人工确认) |

每个工作流在 yaml 中以**步骤序列 + 资源清单**形式定义,Cursor 不自动解析,由对应的 Skill 或编排器按步骤执行。

## 接入一个业务项目

1. 克隆本仓库到本地任意目录
2. 在目标业务项目(如 `broker`)根目录执行链接脚本:
   - Windows:`powershell -File <harness-path>\link-cursor-config.ps1 <broker-path>`
   - macOS/Linux:`bash <harness-path>/link-cursor-config.sh <broker-path>`
3. 链接脚本会把 `.cursor/rules`、`.cursor/skills`、`.cursor/agents`、`.cursor/workflows` 以 Junction/symlink 方式挂到业务项目下,并**复制** `mcp/mcp-template.json` 到目标项目
4. 复制 `.cursor/mcp/mcp-template.json` 为 `.cursor/mcp.json`,填入实际密钥(`.cursor/mcp.json` 已被 gitignore 忽略)
5. 业务项目内的所有 AI 操作即自动遵守本仓库规则;升级规则只需在 harness 仓库 `git pull`

## 关键机制

| 机制 | 入口 |
|------|------|
| **制品链** | `rules/orchestration/stage-contracts.mdc` — 各阶段输入输出契约,子代理通过文件交接 |
| **审查-修复闭环** | 各审查 agent — 不通过则回退给上游修正,最多 5 轮,超限触发人工介入 |
| **人工检查点** | `rules/feedback/human-checkpoint.mdc` — 需求模糊/方案抉择/风险操作时暂停问用户 |
| **记忆固化** | `rules/feedback/correction-detection.mdc` + `agents/shared/memory-consolidator.md` — 用户重复纠正同类错误自动写入规则文件 |
| **全局调试日志** | `skills/shared/harness-debug-logger` — 全轨迹写入 `docs/artifacts/harness-debug.md` |
| **资源冲突检测** | 工作流启动时扫描 harness 自身资源,检测职责重叠/定义矛盾/引用缺失/覆盖空白 |
| **Java 编辑自检** | `rules/feedback/java-edit-self-check.mdc` — `.java` 文件编辑后强制自检注释/判空等,先于编译/Lint/测试门禁 |

## 扩展指引

- **新增编码规范** → `rules/memory/<topic>.mdc`,设置 `globs` 匹配模式
- **新增技能** → `skills/<工作流>/<技能名>/SKILL.md`
- **新增子代理** → `agents/<工作流>/<代理名>.md`
- **新增 MCP** → 在 `.cursor/mcp/mcp-template.json` 中添加配置,在 `rules/memory/mcp-conventions.mdc` 注册表中添加行
- **新增分类映射时** → 同步更新三处分类表:`coding-standards-loader.mdc`、`correction-detection.mdc`、`memory-consolidator.md`(三表必须保持一致)
- **适配新项目** → 编辑 `rules/memory/project-architecture.mdc` 填入分层结构和模块职责;不需要的规则把 `alwaysApply` 改为 `false`;复制 `mcp/mcp-template.json` 为 `mcp.json` 并填入本项目密钥

## 仓库哲学

> 每当 Agent 犯了一个错误,你就花时间设计一个解决方案,让 Agent 再也不会犯同样的错。 — Mitchell Hashimoto

本仓库的所有规则、技能、代理都是这种"沉淀"的产物。如果发现 AI 输出不符合预期,优先考虑:
1. 这条经验能不能写成一条 `.mdc` 规则?
2. 这个工作流能不能拆出一个 skill?
3. 这个任务能不能交给一个专用子代理?

不要靠"下次再提醒一次"。靠仓库。

## 状态

- ⚙️ 当前版本:v2(三工作流渐进体系)
- 📦 资源数:33 rules + 13 skills + 15 agents + 3 workflows + 7 MCP
