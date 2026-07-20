#!/usr/bin/env node
/**
 * 校验 rules-loader.mdc 场景表 与 rules-engine.mjs 路由配置是否同步。
 *
 * 检查项：
 *   1. SCENE_DETECTORS 与 SCENE_TO_ROW 的 key 集合一致
 *   2. SCENE_TO_ROW 的 value 均存在于场景表「任务场景」列
 *   3. 场景表每一行至少被一个 SCENE_TO_ROW 引用（tenant/mq 可共用一行）
 *   4. 场景表引用的规则文件均存在
 *   5. 根目录非 alwaysApply 规则（除 rules-loader）均出现在场景表某行
 *
 * 运行：
 *   node .cursor/scripts/check-rule-routing-sync.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import {
  SCENE_DETECTORS,
  SCENE_TO_ROW,
  getProjectRoot,
  parseScenarioTable,
} from '../hooks/lib/rules-engine.mjs';
const PROJECT_ROOT = getProjectRoot();
const RULES_ROOT = path.join(PROJECT_ROOT, '.cursor', 'rules');
const RULES_LOADER = path.join(RULES_ROOT, 'rules-loader.mdc');

const errors = [];

function fail(code, detail) {
  errors.push(`${code}: ${detail}`);
}

function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) {
    return { alwaysApply: false };
  }
  const alwaysMatch = match[1].match(/^alwaysApply:\s*(true|false)$/m);
  return {
    alwaysApply: alwaysMatch ? alwaysMatch[1] === 'true' : false,
  };
}

function listRootRules() {
  return fs
    .readdirSync(RULES_ROOT, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.mdc'))
    .map((entry) => {
      const fullPath = path.join(RULES_ROOT, entry.name);
      const content = fs.readFileSync(fullPath, 'utf8');
      const meta = parseFrontmatter(content);
      return {
        name: entry.name.replace(/\.mdc$/, ''),
        alwaysApply: meta.alwaysApply,
      };
    });
}

function main() {
  const loaderContent = fs.readFileSync(RULES_LOADER, 'utf8');
  const scenarioTable = parseScenarioTable(loaderContent);
  const tableScenes = new Set(scenarioTable.keys());
  const tableRules = new Set();
  for (const rules of scenarioTable.values()) {
    rules.forEach((rule) => tableRules.add(rule));
  }

  const detectorKeys = new Set(Object.keys(SCENE_DETECTORS));
  const rowKeys = new Set(Object.keys(SCENE_TO_ROW));

  for (const key of detectorKeys) {
    if (!rowKeys.has(key)) {
      fail('DETECTOR_WITHOUT_ROW', `SCENE_DETECTORS.${key} 缺少对应 SCENE_TO_ROW 条目`);
    }
  }
  for (const key of rowKeys) {
    if (!detectorKeys.has(key)) {
      fail('ROW_WITHOUT_DETECTOR', `SCENE_TO_ROW.${key} 缺少对应 SCENE_DETECTORS 条目`);
    }
  }

  const rowTargets = new Set(Object.values(SCENE_TO_ROW));
  for (const target of rowTargets) {
    if (!tableScenes.has(target)) {
      fail('ROW_TARGET_MISSING', `SCENE_TO_ROW 指向的场景不在 rules-loader 表内: ${target}`);
    }
  }

  for (const scene of tableScenes) {
    const covered = [...rowTargets].includes(scene);
    if (!covered) {
      fail('TABLE_ROW_UNCOVERED', `场景表行未被任何 SCENE_TO_ROW 引用: ${scene}`);
    }
  }

  for (const ruleName of tableRules) {
    const direct = path.join(RULES_ROOT, `${ruleName}.mdc`);
    const projectExists = fs
      .existsSync(path.join(RULES_ROOT, 'projects'))
      ? walkProjectRuleExists(ruleName)
      : false;
    if (!fs.existsSync(direct) && !projectExists) {
      fail('TABLE_RULE_MISSING', `场景表引用不存在的规则文件: ${ruleName}.mdc`);
    }
  }

  for (const rule of listRootRules()) {
    if (rule.name === 'rules-loader' || rule.alwaysApply) {
      continue;
    }
    if (!tableRules.has(rule.name)) {
      fail(
        'ROOT_RULE_NOT_ROUTED',
        `根目录规则未出现在场景表任何一行（非 alwaysApply）: ${rule.name}.mdc`,
      );
    }
  }

  if (errors.length > 0) {
    console.error('Rule routing sync validation failed:');
    errors.forEach((item) => console.error(`- ${item}`));
    process.exit(1);
  }

  console.log(
    `Rule routing sync passed (${detectorKeys.size} scenes, ${tableScenes.size} table rows, ${tableRules.size} routed rules)`,
  );
}

function walkProjectRuleExists(ruleName) {
  const projectsDir = path.join(RULES_ROOT, 'projects');
  if (!fs.existsSync(projectsDir)) {
    return false;
  }
  for (const projectDir of fs.readdirSync(projectsDir, { withFileTypes: true })) {
    if (!projectDir.isDirectory()) {
      continue;
    }
    const candidate = path.join(projectsDir, projectDir.name, `${ruleName}.mdc`);
    if (fs.existsSync(candidate)) {
      return true;
    }
  }
  return false;
}

main();
