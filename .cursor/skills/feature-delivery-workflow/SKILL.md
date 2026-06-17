# 全流程交付编排

> 功能交付的总指挥技能，编排从 PRD 到交付完成的完整流程，调度各阶段子代理，管理制品传递和审查点。

## 触发场景

- 用户明确说"做一个新功能"或启动 feature-delivery 工作流
- 需要从 PRD 到完整实现的端到端交付

## 流程总览

```
[可选: 云文档导入] → ① PRD拆分 → ② 头脑风暴 → ③ 概要设计 → [一致性审查] → [HLD发布飞书→人工确认]
  → ④ DDL设计 / API设计 → ⑤ 详细设计 → [一致性审查] → [LLD发布飞书→人工确认]
  → ⑥ 实现计划 → ⑦ 编码 → [规格审查] → [质量审查] → [通用审查]
  → ⑧ 验证 → ⑨ 收尾归档
```

## 工作流启动协议

工作流开始时，**必须按顺序执行以下初始化步骤**：

1. **加载调试日志技能** — 读取 `skills/harness-debug-logger/SKILL.md`，了解日志格式
2. **创建日志文件** — 在 `docs/artifacts/harness-debug.md` 写入"工作流启动"条目
3. **记录规则加载** — 按日志格式记录当前激活的规则列表
4. **资源冲突检测** — **仅扫描 harness 工程自身的激活资源**（`.cursor/rules/` + `.cursor/skills/` + `.cursor/agents/` + `.cursor/workflows/`），检测 harness 配置之间的职责重叠/定义矛盾/引用缺失/覆盖空白；**不扫描**业务项目源码与制品（后者由各阶段的审查子代理负责），将结果写入日志
5. **读取决策记录** — 如 `docs/artifacts/decision-log.md` 存在，读取已有决策

以上初始化完成后，才进入第一个阶段。

## 灵活入口协议（支持中途进入）

工作流不强制从阶段①开始，可由用户指定任意阶段作为入口（如「从详细设计开始」「按 `workflows/feature-delivery/phase-5-lld.yaml` 执行」）。进入目标阶段前，按以下顺序解析入口：

1. **确定起始阶段** — 解析用户指定的阶段（阶段号或 `phase-*.yaml` 文件名）；未指定时默认从阶段①开始。
2. **检查 entry_artifacts** — 读取目标阶段文件的 `entry_artifacts`，逐一检查 `docs/artifacts/` 下对应制品是否存在且非空。
3. **按检查结果分流**：

| 检查结果 | 处理方式 |
|---------|---------|
| 全部存在 | **按顺序处理**：以目标阶段为起点直接继续往后执行，无需询问 |
| 存在缺失 | **暂停并询问用户**（human-checkpoint），给出 A / B 两个选项 |

4. **缺失时给用户的两个选项**：

   - **选项 A — 补齐上游后按顺序处理**：回退到能产出缺失制品的最早阶段，按顺序补齐缺失制品，再回到目标阶段继续。
   - **选项 B — 就地从当前阶段开始**：以目标阶段为新的起点，跳过缺失的上游制品；用用户当前提供的输入直接处理，缺失的上游制品标注为"本次不产出 / 不依赖"。

5. **记录决策** — 将入口选择（起始阶段 + A/B）追加到 `docs/artifacts/decision-log.md`，并在 `harness-debug.md` 记一条"灵活入口"日志。

> 本协议是对"上游制品缺失即停止"的细化：仍然先停下来，但不直接报错退出，而是把"补齐上游"还是"就地开始"的决定权交给用户。

## 步骤执行协议

**每个阶段（含审查点）执行时**，遵循统一的 before/after 日志协议：

**执行前** — 向 `docs/artifacts/harness-debug.md` 追加一条日志，记录：
- 时间戳、阶段名称
- 调度的资源类型和路径（子代理/技能）
- 输入制品列表

**执行后** — 向 `docs/artifacts/harness-debug.md` 追加一条日志，记录：
- 时间戳、阶段名称、耗时
- 输出制品列表
- 结果（成功/失败/需人工介入）

日志条目的具体格式参照 `skills/harness-debug-logger/SKILL.md` 中的定义。

## 各阶段调度说明

### 前置步骤（可选）：PRD 导入

| 项目 | 内容 |
|------|------|
| 动作 | 将云文档（飞书文档、Confluence 等）内容复制到本地 |
| 输出 | `docs/artifacts/prd-source.md` |
| 跳过条件 | 用户直接提供口头需求或已有本地文件时跳过 |

### 阶段①：PRD 功能拆分

| 项目 | 内容 |
|------|------|
| 调度代理 | `agents/prd-splitter` |
| 模式 | 只读 |
| 输入 | `docs/artifacts/prd-source.md`（如存在）或用户口头需求描述 |
| 输出 | `docs/artifacts/feature-list.md` |
| 完成条件 | 功能清单包含优先级、验收标准 |

### 阶段②：头脑风暴

| 项目 | 内容 |
|------|------|
| 调度技能 | `skills/brainstorming` |
| 输入 | `docs/artifacts/feature-list.md` |
| 输出 | `docs/artifacts/brainstorm-result.md` |
| 完成条件 | 至少 2 种方案对比 + 推荐方案 |
| 人工检查点 | 如有待确认事项，暂停等用户决策 |

### 阶段③：概要设计

| 项目 | 内容 |
|------|------|
| 调度代理 | `agents/architect-hld` |
| 模式 | 只读 |
| 输入 | `feature-list.md` + `brainstorm-result.md` |
| 输出 | `docs/artifacts/hld.md` |
| 完成条件 | 包含模块划分、接口概览、数据流 |

### 审查点 A：HLD 一致性审查

| 项目 | 内容 |
|------|------|
| 调度代理 | `agents/consistency-reviewer` |
| 输入 | `feature-list.md` + `hld.md` |
| 校验 | 功能点↔模块映射完整性 |
| 回退 | 不通过回退给 `architect-hld`，最多 5 轮 |

### HLD 发布飞书 & 人工确认

| 项目 | 内容 |
|------|------|
| 调度技能 | `skills/hld-to-feishu` |
| 输入 | `docs/artifacts/hld.md` |
| 动作 | 发布到飞书云文档，等待人工审阅确认 |
| 确认通过 | 继续进入 DDL/API 设计 |
| 需要修改 | 回退给 `architect-hld` 修正后重新发布 |

### 阶段④：DDL 与 API 设计（可并行）

| 项目 | DDL | API |
|------|-----|-----|
| 调度代理 | `agents/db-ddl` | `agents/api-contract` |
| 模式 | 读写 | 读写 |
| 输入 | `hld.md` | `hld.md` |
| 输出 | `docs/artifacts/ddl.md` | `docs/artifacts/api-contract.md` |

### 阶段⑤：详细设计

| 项目 | 内容 |
|------|------|
| 调度代理 | `agents/lld-author` |
| 模式 | 只读 |
| 输入 | `hld.md` + `ddl.md` + `api-contract.md` |
| 输出 | `docs/artifacts/lld.md` |
| 完成条件 | 包含类设计、方法签名、业务流程 |

### 审查点 B：LLD 一致性审查

| 项目 | 内容 |
|------|------|
| 调度代理 | `agents/consistency-reviewer` |
| 输入 | `hld.md` + `ddl.md` + `api-contract.md` + `lld.md` |
| 校验 | LLD↔HLD 接口覆盖、DDL↔Entity 一致、API↔方法签名匹配 |
| 回退 | 不通过回退给 `lld-author`，最多 5 轮 |

### LLD 发布飞书 & 人工确认

| 项目 | 内容 |
|------|------|
| 调度技能 | `skills/lld-to-feishu` |
| 输入 | `docs/artifacts/lld.md` |
| 动作 | 发布到飞书云文档，等待人工审阅确认 |
| 确认通过 | 继续进入实现计划 |
| 需要修改 | 回退给 `lld-author` 修正后重新发布 |

### 阶段⑥：实现计划

| 项目 | 内容 |
|------|------|
| 调度代理 | `agents/impl-planner` |
| 调度技能 | `skills/writing-plans` |
| 模式 | 只读 |
| 输入 | `lld.md`（必读）+ `hld.md`（参考） |
| 输出 | `docs/artifacts/impl-plan.md` |
| 完成条件 | 子任务清单含依赖、验证方式、并行策略 |

### 阶段⑦：编码实现

| 项目 | 内容 |
|------|------|
| 调度代理 | `agents/implementer` |
| 调度技能 | `skills/codegen-guard`（新文件时） |
| 模式 | 读写 |
| 输入 | `docs/artifacts/impl-plan.md` |
| 完成条件 | 所有子任务实现完毕且各自测试通过 |

### 审查链（编码完成后依次执行）

| 顺序 | 审查者 | 审查内容 | 最多轮数 |
|------|--------|----------|----------|
| 1 | `agents/spec-reviewer` | 代码是否按 LLD 设计实现 | 5 |
| 2 | `agents/code-quality-reviewer` | 代码质量（坏味道、可维护性） | 5 |
| 3 | `agents/code-reviewer` | 最终综合审查（正确性、回归、规范） | 5 |

每层审查不通过 → 回退给 `implementer` 修复 → 从该层重新审查。

### 阶段⑧：最终验证

| 项目 | 内容 |
|------|------|
| 调度技能 | `skills/done-verify` |
| 检查 | 编译通过、测试全绿、Lint 干净、diff 范围合理 |

### 阶段⑨：收尾归档

| 项目 | 内容 |
|------|------|
| 动作 | 向 `harness-debug.md` 追加"制品归档"条目和"工作流完成"条目 |
| 动作 | 归档 `docs/artifacts/`（含 `harness-debug.md`）到 `archive/{date}-{task}/` |

## 制品传递规则

1. 每个阶段**开始前**必须确认上游制品存在
2. 如果上游制品缺失，按「灵活入口协议」**暂停并询问用户**（A 补齐上游 / B 就地从当前阶段开始），不直接退出
3. 每个阶段**完成后**产出制品到固定路径
4. 下游代理必须**先读取**上游制品再开始工作
5. 决策记录 `decision-log.md` 全程可追加，所有代理启动时必须读取

## 异常处理

| 场景 | 处理方式 |
|------|----------|
| 上游制品缺失 | 暂停并按「灵活入口协议」询问用户：A 补齐上游 / B 就地从当前阶段开始 |
| 审查超过 5 轮未通过 | 暂停，标记人工介入 |
| 用户决策影响已有制品 | 回退到受影响的最早阶段重新执行 |
| 需求变更 | 从 PRD 拆分阶段重新开始 |
