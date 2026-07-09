---
name: git-worktree
description: >-
  为可并行子任务创建隔离 git worktree 和分支，支持多子代理并行开发避免冲突。
  在 impl-plan 中有 2 个以上无文件冲突的可并行子任务、或用户要求并行开发时使用。
  不用于仅 1 个子任务、子任务有文件级依赖、仓库有未提交改动或非 git 仓库时。
---

# Git Worktree 并行开发指南

## 用途
当实现计划中存在多个可并行的子任务时，使用 git worktree 创建隔离的工作目录，让多个子代理各自在独立分支上并行开发，避免分支切换冲突和文件覆盖。

## 触发时机
- 实现计划（`docs/artifacts/impl-plan.md`）中识别出 2 个以上可并行子任务
- 由 workflow YAML 在"派发并行任务"步骤显式调用
- 手动场景：用户明确要求并行开发多个子任务

## 前提条件
- 当前目录是一个 git 仓库
- 主分支（main/master/develop）状态干净，无未提交改动
- 并行子任务之间无文件级依赖（不修改同一文件）

## 操作流程

### 1. 评估并行可行性

从 `docs/artifacts/impl-plan.md` 中提取子任务列表，逐对检查文件依赖：

```
子任务 A 修改文件集: {fileA1, fileA2, ...}
子任务 B 修改文件集: {fileB1, fileB2, ...}
交集 = A ∩ B
```

- 交集为空 → 可并行
- 交集非空 → 有冲突风险，需串行或拆分

输出并行分组方案：
```markdown
## 并行分组
- **组 1**（可并行）: 子任务 1、子任务 3
- **组 2**（可并行）: 子任务 2、子任务 5
- **串行队列**: 子任务 4（依赖组 1 产出）
```

### 2. 创建 Worktree

为每个并行子任务创建独立的 worktree：

```bash
# 从主分支创建 worktree + 新分支
git worktree add ../worktree-task-{N} -b feature/{feature-slug}/task-{N}

# 示例：
git worktree add ../worktree-task-1 -b feature/user-registration/task-1-entity
git worktree add ../worktree-task-2 -b feature/user-registration/task-2-controller
```

命名约定：
- worktree 目录：`../worktree-task-{N}`（与主仓库同级）
- 分支名：`feature/{feature-slug}/task-{N}-{简述}`

### 3. 在 Worktree 中执行

每个并行 agent 在各自的 worktree 目录中工作：

- 读取共享制品（从主仓库的 `docs/artifacts/` 中读取，路径需调整为绝对路径或相对路径 `../../主仓库/docs/artifacts/`）
- 执行各自的子任务
- 写入独立的调试日志（`harness-debug-worker-{N}.md`）
- 完成后在各自分支提交

### 4. 合并回主分支

所有并行任务完成后，按序合并：

```bash
# 回到主仓库
cd {主仓库路径}

# 逐个合并并行分支
git merge feature/{feature-slug}/task-1-entity --no-ff
git merge feature/{feature-slug}/task-2-controller --no-ff

# 如有冲突，暂停并触发人工检查点
```

合并策略：
- 使用 `--no-ff` 保留分支历史
- 按依赖顺序合并（被依赖的先合并）
- 每次合并后运行编译+测试验证
- 冲突无法自动解决时，触发人工检查点

### 5. 清理 Worktree

合并完成并验证通过后，清理临时 worktree：

```bash
# 移除 worktree
git worktree remove ../worktree-task-1
git worktree remove ../worktree-task-2

# 删除已合并的分支
git branch -d feature/{feature-slug}/task-1-entity
git branch -d feature/{feature-slug}/task-2-controller
```

### 6. 合并调试日志

将各 worker 的独立日志合并为主日志：

```bash
# 按时间戳排序合并
# harness-debug-worker-1.md + harness-debug-worker-2.md → harness-debug.md
```

## 调试日志约定
- 各并行 agent 写入 `docs/artifacts/harness-debug-worker-{N}.md`
- 收尾阶段将所有 worker 日志按时间戳排序合并入 `docs/artifacts/harness-debug.md`
- 合并后删除 worker 级日志文件

## 异常处理

| 场景 | 处理方式 |
|------|---------|
| 并行任务之一编译失败 | 隔离在其 worktree 中修复，不影响其他 worktree |
| 合并时冲突 | 暂停流程，触发人工检查点，记录到 decision-log.md |
| 某个并行任务阻塞 | 其他已完成的任务先合并，阻塞任务后续串行处理 |
| Worktree 创建失败 | 回退到串行执行模式 |

## 关键约束
- worktree 目录必须在主仓库外部（同级目录），避免嵌套 git 仓库
- 并行 agent 之间禁止直接通信，只通过制品文件交换信息
- 每次合并后必须通过编译+测试验证
- 所有 worktree 必须在工作流结束前清理完毕
- 最大并行数建议不超过 3（受限于 AI 上下文管理能力）
