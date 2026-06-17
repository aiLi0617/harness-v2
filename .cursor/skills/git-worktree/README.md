# git-worktree 使用说明

> 用 git worktree 为可并行的子任务创建隔离工作目录，让多个子代理在独立分支上并行开发，避免分支切换冲突和文件覆盖。Agent 执行细节以 [`SKILL.md`](./SKILL.md) 为准。

## 这个 Skill 是做什么的

当实现计划中存在多个互不依赖的子任务时，本技能负责：评估并行可行性（按文件依赖判定）、为每个并行任务创建 worktree + 独立分支、在隔离目录中执行、按依赖顺序合并回主分支、清理 worktree、合并各 worker 调试日志。

## 适用场景

- `docs/artifacts/impl-plan.md` 中识别出 2 个以上可并行子任务
- workflow YAML 在"派发并行任务"步骤显式调用
- 用户明确要求并行开发多个子任务

## 前提条件

- 当前目录是 git 仓库
- 主分支（main/master/develop）干净，无未提交改动
- 并行子任务之间无文件级依赖（不修改同一文件）

## 操作流程

```
1. 评估并行可行性  → 按文件交集判定可并行/需串行，输出并行分组
2. 创建 worktree   → git worktree add ../worktree-task-{N} -b feature/{slug}/task-{N}
3. 在 worktree 执行 → 各 agent 在独立目录工作，写 harness-debug-worker-{N}.md
4. 合并回主分支    → --no-ff，按依赖顺序，每次合并后编译+测试
5. 清理 worktree   → git worktree remove + 删除已合并分支
6. 合并调试日志    → worker 日志按时间戳合并入 harness-debug.md
```

## 关键约束

- worktree 目录必须在主仓库外部（同级），避免嵌套 git 仓库
- 并行 agent 之间禁止直接通信，只通过制品文件交换信息
- 每次合并后必须通过编译+测试验证
- 工作流结束前清理所有 worktree
- 最大并行数建议不超过 3

## 相关资源

| 资源 | 关系 |
|------|------|
| [`writing-plans`](../writing-plans/SKILL.md) | 产出含并行策略的 impl-plan.md |
| `harness-debug-logger` | 定义 worker 级日志与合并约定 |
| `git-branch.mdc` | 分支命名规范 |
