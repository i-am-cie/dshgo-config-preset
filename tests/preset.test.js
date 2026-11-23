'use strict';

/**
 * 预设跨字段一致性测试（node:test，零依赖）。
 *
 * JSON Schema（schema/preset.schema.json）只能校验单字段类型与枚举，
 * 这里补充 Schema 表达不了的跨字段约束：
 *  - id 唯一性（插件 / 模型接口 / 自动化任务 / 胶囊）
 *  - defaultModel 必须指向本接口 models 列表中的某个模型
 *  - pluginSeats 引用的插件必须存在于 plugins 列表
 *  - cron / event 触发的自动化任务必须带对应字段
 *  - API Key 引用必须符合 DSH_SECRET_* 命名规范
 */

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const presetsDir = path.join(__dirname, '..', 'presets');

const PLUGIN_SOURCES = ['local', 'github', 'npm'];
const PROVIDERS = ['openai', 'ollama', 'openai-compat', 'anthropic', 'google', 'deepseek'];
const AUTOMATION_TRIGGERS = ['cron', 'event', 'manual'];
const HOOK_PHASES = ['preInstall', 'postInstall', 'preReload', 'postReload'];

function loadPresets() {
  return fs
    .readdirSync(presetsDir)
    .filter((f) => f.endsWith('.json'))
    .sort()
    .map((file) => {
      const full = path.join(presetsDir, file);
      const data = JSON.parse(fs.readFileSync(full, 'utf8'));
      return { file, name: file.replace(/\.json$/, ''), data };
    });
}

const presets = loadPresets();

function assertUnique(ids, label) {
  const seen = new Set();
  for (const id of ids) {
    assert.ok(!seen.has(id), `${label} id 重复: ${id}`);
    seen.add(id);
  }
}

for (const { file, name, data } of presets) {
  test(`[${file}] 顶层必填字段齐全`, () => {
    for (const key of ['version', 'name', 'plugins', 'modelProfiles', 'ui', 'automations', 'hooks']) {
      assert.ok(Object.prototype.hasOwnProperty.call(data, key), `缺少顶层字段: ${key}`);
    }
    assert.match(data.version, /^\d+\.\d+\.\d+$/, `version 不是语义化版本号: ${data.version}`);
    assert.strictEqual(data.name, name, `预设 name 与文件名不一致: ${data.name} != ${name}`);
  });

  test(`[${file}] 插件列表合法且 id 唯一`, () => {
    assert.ok(Array.isArray(data.plugins), 'plugins 必须是数组');
    const ids = [];
    for (const p of data.plugins) {
      assert.ok(p.id && typeof p.id === 'string', '插件 id 必须为非空字符串');
      ids.push(p.id);
      assert.strictEqual(typeof p.enabled, 'boolean', `插件 ${p.id} 的 enabled 必须为布尔值`);
      assert.ok(PLUGIN_SOURCES.includes(p.source), `插件 ${p.id} source 非法: ${p.source}`);
      if (p.source === 'github') {
        assert.ok(/^[^/]+\/[^/]+$/.test(p.repo || ''), `插件 ${p.id} repo 不符合 owner/name: ${p.repo}`);
      }
    }
    assertUnique(ids, '插件');
  });

  test(`[${file}] 模型接口合法，defaultModel 指向已有模型`, () => {
    assert.ok(Array.isArray(data.modelProfiles), 'modelProfiles 必须是数组');
    const profileIds = [];
    for (const profile of data.modelProfiles) {
      assert.ok(profile.id && typeof profile.id === 'string', '模型接口 id 必须为非空字符串');
      profileIds.push(profile.id);
      assert.ok(PROVIDERS.includes(profile.provider), `模型接口 ${profile.id} provider 非法: ${profile.provider}`);
      assert.ok(Array.isArray(profile.models) && profile.models.length > 0, `模型接口 ${profile.id} models 不能为空`);
      assert.match(profile.apiKeyRef || '', /^DSH_SECRET_[A-Z0-9_]+$/, `模型接口 ${profile.id} apiKeyRef 非法: ${profile.apiKeyRef}`);

      const modelIds = [];
      for (const m of profile.models) {
        assert.ok(m.id && typeof m.id === 'string', `模型 ${profile.id} 存在空 id`);
        assert.ok(typeof m.name === 'string' && m.name.length > 0, `模型 ${m.id} name 必须为非空字符串`);
        assert.ok(Number.isInteger(m.contextLength) && m.contextLength >= 1, `模型 ${m.id} contextLength 必须为正整数`);
        assert.strictEqual(typeof m.supportsTools, 'boolean', `模型 ${m.id} supportsTools 必须为布尔值`);
        modelIds.push(m.id);
      }
      assertUnique(modelIds, `模型接口 ${profile.id} 的模型`);
      assert.ok(modelIds.includes(profile.defaultModel), `模型接口 ${profile.id} defaultModel 未在 models 中: ${profile.defaultModel}`);
    }
    assertUnique(profileIds, '模型接口');
  });

  test(`[${file}] pluginSeats 引用的插件均存在`, () => {
    const pluginIds = new Set(data.plugins.map((p) => p.id));
    const seats = (data.ui && data.ui.pluginSeats) || {};
    for (const [seat, pluginId] of Object.entries(seats)) {
      assert.ok(pluginIds.has(pluginId), `插件座位 ${seat} 指向不存在的插件: ${pluginId}`);
    }
  });

  test(`[${file}] UI 胶囊 id 唯一且字段齐全`, () => {
    const capsules = (data.ui && data.ui.capsules) || [];
    const ids = [];
    for (const c of capsules) {
      assert.ok(c.id && typeof c.id === 'string', '胶囊 id 必须为非空字符串');
      assert.ok(c.label && typeof c.label === 'string', `胶囊 ${c.id} label 必须为非空字符串`);
      assert.ok(c.action && typeof c.action === 'string', `胶囊 ${c.id} action 必须为非空字符串`);
      ids.push(c.id);
    }
    assertUnique(ids, '胶囊');
  });

  test(`[${file}] 自动化任务合法，触发条件字段齐全`, () => {
    assert.ok(Array.isArray(data.automations), 'automations 必须是数组');
    const ids = [];
    for (const a of data.automations) {
      assert.ok(a.id && typeof a.id === 'string', '自动化任务 id 必须为非空字符串');
      ids.push(a.id);
      assert.ok(AUTOMATION_TRIGGERS.includes(a.trigger), `自动化任务 ${a.id} trigger 非法: ${a.trigger}`);
      assert.strictEqual(typeof a.enabled, 'boolean', `自动化任务 ${a.id} enabled 必须为布尔值`);
      if (a.trigger === 'cron') {
        assert.ok(typeof a.cronExpression === 'string' && a.cronExpression.length > 0, `自动化任务 ${a.id} cron 触发缺少 cronExpression`);
      }
      if (a.trigger === 'event') {
        assert.ok(typeof a.event === 'string' && a.event.length > 0, `自动化任务 ${a.id} event 触发缺少 event`);
      }
    }
    assertUnique(ids, '自动化任务');
  });

  test(`[${file}] hooks 四个阶段均为字符串数组`, () => {
    assert.ok(data.hooks && typeof data.hooks === 'object', 'hooks 必须为对象');
    for (const phase of HOOK_PHASES) {
      const hooks = data.hooks[phase];
      if (hooks !== undefined) {
        assert.ok(Array.isArray(hooks), `hooks.${phase} 必须为数组`);
        for (const h of hooks) {
          assert.ok(typeof h === 'string' && h.length > 0, `hooks.${phase} 元素必须为非空字符串`);
        }
      }
    }
  });
}

test('presets 目录至少包含三套预设', () => {
  assert.ok(presets.length >= 3, `预期至少 3 个预设，实际 ${presets.length} 个`);
});
