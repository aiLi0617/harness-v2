#!/usr/bin/env node
/**
 * Harness 规则注入 Hook — beforeSubmitPrompt
 *
 * 用途：
 *   在用户发送 Agent 消息前，检测是否为编码类任务；若是，则按 rules-loader 场景表
 *   与项目 globs 机械读取 .mdc 规则正文，注入 Cursor 的 additional_context。
 *   解决「非 Workflow 会话中 Agent 不主动 Read 规则导致规范丢失」的问题。
 *
 * 触发：
 *   .cursor/hooks.json → beforeSubmitPrompt（matcher: UserPromptSubmit）
 *
 * 输入（stdin JSON，字段因 Cursor 版本可能略有差异）：
 *   - prompt / user_message：用户消息
 *   - open_files / attached_files：上下文文件路径
 *   - conversation_id / session_id：会话标识
 *
 * 输出（stdout JSON）：
 *   - 编码意图且命中规则 → { "additional_context": "[Harness 规则机械注入]..." }
 *   - 非编码或无规则     → {}
 *
 * 依赖：
 *   - Node.js（node 在 PATH 中）
 *   - ./lib/rules-engine.mjs
 *
 * 参见：.cursor/rules/rules-loader.mdc「Hook 机械加载」
 */
import {
  bootstrapRules,
  getSessionId,
  isCodingIntent,
  readStdinJson,
  writeJsonStdout,
  writeSessionState,
} from './lib/rules-engine.mjs';

/** 单次注入体积上限，超出则截断并提示查看源文件 */
const MAX_INJECTION_CHARS = 150000;

try {
  const input = readStdinJson();
  const sessionId = getSessionId(input);
  const { ctx, result, message } = bootstrapRules(input);

  // 非编码任务或未解析到规则：不注入，避免无关 token 开销
  if (!isCodingIntent(ctx) || result.rules.length === 0 || !message) {
    writeJsonStdout({});
    process.exit(0);
  }

  let injection = message;
  let truncated = false;
  if (injection.length > MAX_INJECTION_CHARS) {
    injection = `${injection.slice(0, MAX_INJECTION_CHARS)}\n\n[Harness] 规则注入已截断，完整规则请查看 .cursor/rules/ 对应文件。`;
    truncated = true;
  }

  // 写入会话状态，供 preToolUse 写码门禁对账
  writeSessionState(sessionId, {
    scenes: result.scenes,
    rulePaths: result.rules.map((rule) => rule.relativePath),
    truncated,
    source: 'beforeSubmitPrompt',
  });

  writeJsonStdout({
    additional_context: injection,
  });
  process.exit(0);
} catch (error) {
  // 失败时不阻断用户发消息，仅 stderr 记录
  process.stderr.write(`rules-bootstrap beforeSubmitPrompt failed: ${error.message}\n`);
  writeJsonStdout({});
  process.exit(0);
}
