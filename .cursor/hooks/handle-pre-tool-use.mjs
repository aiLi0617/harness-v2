#!/usr/bin/env node
/**
 * Harness 写码门禁 Hook — preToolUse
 *
 * 用途：
 *   在 Agent 调用 Write / StrReplace / ApplyPatch / EditNotebook 写业务源码前，
 *   检查本会话是否已注入 Harness 编码规则；若无或目标路径需额外项目规则，则同步注入。
 *   规则加载结果为空时返回 permission: deny，阻断无规范写码。
 *
 * 触发：
 *   .cursor/hooks.json → preToolUse（matcher: Write|StrReplace|ApplyPatch|EditNotebook）
 *
 * 门禁范围：
 *   - 业务源码：*.java, *.kt, Mapper.xml, *.sql, pom.xml, application*.yml 等
 *   - 排除：.cursor/rules、hooks、agents、skills、workflows（Harness 自身配置可自由编辑）
 *
 * 输出（stdout JSON）：
 *   - 非写码工具或非业务路径 → { "permission": "allow" }
 *   - 已有完整注入           → { "permission": "allow" }
 *   - 注入成功               → { "permission": "allow", "agent_message": "..." }
 *   - 规则为空               → { "permission": "deny", ... }
 *
 * 依赖：./lib/rules-engine.mjs、Node.js
 * 参见：.cursor/rules/rules-loader.mdc「Hook 机械加载」
 */
import {
  bootstrapRules,
  collectPaths,
  getSessionId,
  getToolName,
  getWriteTargetPath,
  isSourceWritePath,
  readSessionState,
  readStdinJson,
  resolveRules,
  writeJsonStdout,
  writeSessionState,
  collectPrompt,
} from './lib/rules-engine.mjs';

/** Cursor 写文件类工具名（大小写不敏感） */
const WRITE_TOOLS = new Set(['write', 'strreplace', 'applypatch', 'editnotebook']);
/** agent_message 体积上限 */
const MAX_AGENT_MESSAGE_CHARS = 120000;

function isWriteTool(toolName) {
  return WRITE_TOOLS.has(String(toolName || '').toLowerCase());
}

/** 目标路径是否命中尚未注入的项目特化规则（如 broker-* globs） */
function needsAdditionalProjectRules(state, targetPath, input) {
  if (!targetPath) {
    return false;
  }
  const ctx = {
    prompt: collectPrompt(input),
    paths: [...collectPaths(input), targetPath],
  };
  const fresh = resolveRules(ctx);
  const previous = new Set(state?.rulePaths || []);
  return fresh.rules.some((rule) => !previous.has(rule.relativePath));
}

try {
  const input = readStdinJson();
  const toolName = getToolName(input);
  const targetPath = getWriteTargetPath(input);

  // 非写码工具或 Harness 配置路径：直接放行
  if (!isWriteTool(toolName) || !isSourceWritePath(targetPath)) {
    writeJsonStdout({ permission: 'allow' });
    process.exit(0);
  }

  const sessionId = getSessionId(input);
  const state = readSessionState(sessionId);
  const stale =
    !state ||
    !Array.isArray(state.rulePaths) ||
    state.rulePaths.length === 0 ||
    needsAdditionalProjectRules(state, targetPath, input);

  // 本会话已注入且项目规则已覆盖目标路径
  if (!stale) {
    writeJsonStdout({ permission: 'allow' });
    process.exit(0);
  }

  const pathsInput = {
    ...input,
    open_files: [...collectPaths(input), targetPath],
  };
  const { result, message } = bootstrapRules(pathsInput);

  // 无法加载任何规则：阻断写码（failClosed 由 hooks.json 控制脚本崩溃行为）
  if (result.rules.length === 0 || !message) {
    writeJsonStdout({
      permission: 'deny',
      user_message: '写码门禁：未能加载 Harness 编码规则，请确认 .cursor/rules 已链接且 Node.js 可用。',
      agent_message:
        '写码被 Hook 阻断：规则加载结果为空。请用户确认 link-cursor-config 已执行，并重新发送编码请求。',
    });
    process.exit(0);
  }

  writeSessionState(sessionId, {
    scenes: result.scenes,
    rulePaths: result.rules.map((rule) => rule.relativePath),
    targetPath,
    source: 'preToolUse',
  });

  let agentMessage = [
    '[Harness 写码门禁] 已机械注入以下规则，请严格遵守后再写入文件。',
    `目标文件: ${targetPath}`,
    `规则: ${result.rules.map((rule) => rule.relativePath).join(', ')}`,
    '编码前须输出 [规则加载报告] 与上述列表对账。',
    '---',
    message,
  ].join('\n');

  if (agentMessage.length > MAX_AGENT_MESSAGE_CHARS) {
    agentMessage = `${agentMessage.slice(0, MAX_AGENT_MESSAGE_CHARS)}\n\n[Harness] agent_message 已截断。`;
  }

  writeJsonStdout({
    permission: 'allow',
    agent_message: agentMessage,
  });
  process.exit(0);
} catch (error) {
  // 脚本异常时 fail-open，避免锁死 Harness 配置编辑；见 hooks.json failClosed: false
  process.stderr.write(`rules-bootstrap preToolUse failed: ${error.stack || error.message}\n`);
  writeJsonStdout({ permission: 'allow' });
  process.exit(0);
}
