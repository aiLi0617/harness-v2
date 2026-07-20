#!/usr/bin/env node
/**
 * Harness 规则 Hook — sessionStart
 *
 * 用途：
 *   新 Agent 会话开始时，清理 .cursor/hooks/state/ 下超过 24 小时的注入状态文件，
 *   避免磁盘堆积与过期会话 ID 干扰写码门禁判断。
 *
 * 触发：.cursor/hooks.json → sessionStart
 * 输出：{}（无 additional_context）
 */
import { pruneOldState, readStdinJson, writeJsonStdout } from './lib/rules-engine.mjs';

try {
  readStdinJson();
  pruneOldState();
  writeJsonStdout({});
  process.exit(0);
} catch (error) {
  process.stderr.write(`rules-bootstrap sessionStart failed: ${error.message}\n`);
  writeJsonStdout({});
  process.exit(0);
}
