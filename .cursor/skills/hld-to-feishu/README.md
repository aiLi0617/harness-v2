# hld-to-feishu 使用说明

> 将概要设计（HLD）发布到飞书云文档，供架构师/技术负责人审阅确认；确认通过后进入 DDL/API 设计，否则回退修改。Agent 执行细节以 [`SKILL.md`](./SKILL.md) 为准。

## 这个 Skill 是做什么的

读取本地 `hld.md`，通过飞书文档 API 创建或更新云文档，向用户展示链接与审阅检查清单，然后**阻塞等待人工确认**，并按确认/修改的响应决定继续或回退。

## 适用场景

- 概要设计（HLD）通过一致性审查（consistency-review-1）后

## 输入

| 制品 | 路径 | 必须 |
|------|------|------|
| 概要设计 | `docs/artifacts/hld.md` | 是 |
| 飞书文档链接记录 | `docs/artifacts/feishu-doc-links.md` | 否（重新发布时读取） |

## 执行流程

```
1. 读取本地 hld.md
2. 发布到飞书   → 首次创建并记录 URL；重发则更新同一文档并追加修改说明
3. 展示审阅清单 → 功能覆盖 / 模块边界 / 接口概览 / 数据流 / 技术选型 / 非功能 / 无过度设计
4. 等待人工确认 → 阻塞
5. 处理响应     → 确认→进入 DDL/API；修改→回退 architect-hld 后重发
```

## 产出物

| 产出 | 路径 |
|------|------|
| 飞书文档链接记录 | `docs/artifacts/feishu-doc-links.md` |
| 决策记录 | `docs/artifacts/decision-log.md` |
| harness 日志 | `docs/artifacts/harness-debug.md` |

## 关键约束

- 发布前必须确认 HLD 一致性审查已通过
- 飞书链接必须持久化，支持后续更新
- 人工确认为阻塞操作，未确认前不得进入 DDL/API
- 修改回退后更新同一文档，不创建新文档

## 相关资源

| 资源 | 关系 |
|------|------|
| `feishu-mcp` | 飞书云文档发布所需 MCP（见 `mcp.mdc`） |
| [`lld-to-feishu`](../lld-to-feishu/SKILL.md) | LLD 阶段的对应发布技能 |
| `architect-hld` | 修改回退的目标代理 |
