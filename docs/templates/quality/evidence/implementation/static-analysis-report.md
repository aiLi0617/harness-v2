# 静态分析机械报告

## Run 001

- 时间：{timestamp}
- 代码版本：{commit-or-worktree-hash}
- 工具/版本/规则集：{tool-version-rules}
- 命令：`{command}`
- 结果：{PASS|FAIL|NOT_RUN}
- 告警数量：{counts-by-severity}

## 原始发现索引

| 工具 ID | 严重度 | 文件:行 | 信息 | 报告链接 |
|---|---|---|---|---|
| {id} | {tool-severity} | {location} | {message} | {path} |

## 扫描范围与限制

{included-excluded-dataflow-depth-and-failures}

> 人工解释、误报判断和门禁级别写入 `quality/gates/implementation/static-analysis.md`。
