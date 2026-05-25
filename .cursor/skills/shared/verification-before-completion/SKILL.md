# 完成前验证检查清单

## 用途
在任何任务标记"完成"前，强制执行一套验证检查清单，确保不带遗漏问题交付。该技能是所有工作流收尾阶段的最后一道门禁。

## 触发时机
- 任务即将完成时（AI 准备声明"已完成"之前）
- 由 workflow YAML 在收尾阶段强制调用，不依赖 AI 自觉

## 检查清单

### 第一关：编译检查
- [ ] 项目编译通过，无编译错误
- [ ] 无新增的编译警告（或已记录为已知问题）
- **失败处理**：停止后续检查，回退给 implementer 修复编译问题

### 第二关：测试检查
- [ ] 所有已有单元测试通过
- [ ] 所有已有集成测试通过
- [ ] 新增功能有对应的测试用例
- [ ] 测试覆盖率不低于变更前（如有覆盖率要求）
- **失败处理**：停止后续检查，回退给 implementer 修复失败的测试

### 第三关：Lint / 静态分析检查
- [ ] 无新增 Lint 错误
- [ ] 无新增 Lint 警告（或已审议忽略）
- [ ] 静态分析工具（如 SpotBugs、SonarLint）无新增问题
- **失败处理**：回退给 implementer 修复 Lint 问题

### 第四关：变更范围检查
- [ ] `git diff` 中每行改动都能追溯到任务需求
- [ ] 无无关的格式化变更
- [ ] 无无关的重构变更
- [ ] 无意外修改的公共模块
- **失败处理**：要求 implementer 回退无关改动或提供合理解释

### 第五关：遗留项检查
- [ ] 代码中无新增 `TODO`、`FIXME`、`HACK` 注释（或已记录到跟踪系统）
- [ ] 无调试用途的临时代码（`System.out.println`、`console.log`、硬编码测试数据等）
- [ ] 无被注释掉的代码块
- **失败处理**：回退给 implementer 清理遗留项

### 第六关：制品完整性检查
- [ ] 所有上游制品（PRD/HLD/LLD/DDL/API）与最终代码一致
- [ ] `docs/artifacts/decision-log.md` 已记录所有人工决策
- [ ] `docs/artifacts/harness-debug.md` 日志完整
- [ ] 审查报告已归档
- **失败处理**：补齐缺失制品后重新验证

### 第七关：安全检查
- [ ] 无硬编码的密钥、密码、Token
- [ ] 无敏感信息泄露（日志中不输出密码/身份证等）
- [ ] SQL 参数化，无拼接注入风险
- [ ] 用户输入有校验，无 XSS/注入向量
- **失败处理**：回退给 implementer 修复安全问题（阻塞级别）

### 第八关：规则交叉引用检查（仅当变更含 `.cursor/rules/**/*.mdc` 时）
- [ ] 运行检查脚本通过（Windows: `.cursor/scripts/check-rule-cross-refs.ps1`；macOS/Linux: `bash .cursor/scripts/check-rule-cross-refs.sh`）
- [ ] 新增规则已在 `coding-standards-loader.mdc` 场景表登记（如需组合加载）
- **失败处理**：移除叶子规则中的跨文件引用，或改在 loader 场景表并列加载

## 输出

验证通过时：
```
## 完成前验证 — 通过
- **时间**: YYYY-MM-DD HH:mm:ss
- **任务**: {task-name}
- **检查项**: 7/7 全部通过
- **状态**: 可进入归档阶段
```

验证不通过时：
```
## 完成前验证 — 未通过
- **时间**: YYYY-MM-DD HH:mm:ss
- **任务**: {task-name}
- **通过**: N/7
- **失败项**:
  - 第 N 关 {关卡名}: {失败原因摘要}
- **处理**: 回退给 {agent} 修复
```

## 与 feedback 层规则的关系
本技能负责**编排何时检查、按什么顺序检查**；具体的检查标准由 feedback 层门禁规则定义（compilation-guard、test-guard、lint-guard、change-scope-guard，通过 loader 或 alwaysApply 自动加载）。

## 关键约束
- 检查顺序固定，前序关卡未通过时不执行后续关卡（快速失败）
- 每个关卡的失败都会生成一条 harness-debug.md 日志
- 安全检查为阻塞级别，不可跳过
- 验证结果写入 `docs/artifacts/verification-report.md`
