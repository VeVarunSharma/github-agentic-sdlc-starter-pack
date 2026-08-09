// scripts/test/render.test.mjs
// Unit tests for the render-managed-settings renderer logic.
// Run via: node --test scripts/test/render.test.mjs
// Or via: npm test

import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');

// ─── String-aware JSONC parser ───────────────────────────────────────────────

function parseJsonc(src) {
  let result = '';
  let i = 0;
  while (i < src.length) {
    if (src[i] === '"') {
      // Copy string verbatim (handle escapes)
      result += src[i++];
      while (i < src.length) {
        if (src[i] === '\\') { result += src[i] + src[i + 1]; i += 2; continue; }
        if (src[i] === '"') { result += src[i++]; break; }
        result += src[i++];
      }
    } else if (src[i] === '/' && src[i + 1] === '/') {
      // Line comment — skip to end of line
      while (i < src.length && src[i] !== '\n') i++;
    } else if (src[i] === '/' && src[i + 1] === '*') {
      // Block comment
      i += 2;
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i++;
      i += 2;
    } else {
      result += src[i++];
    }
  }
  result = result.replace(/,(\s*[}\]])/g, '$1');
  return JSON.parse(result);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function substitute(text, tokenMap) {
  let result = text;
  for (const [token, value] of Object.entries(tokenMap)) {
    result = result.split(token).join(value);
  }
  return result;
}

function deepStripCommentKeys(obj) {
  if (Array.isArray(obj)) return obj.map(deepStripCommentKeys);
  if (obj && typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj)
        .filter(([k]) => !k.startsWith('_comment'))
        .map(([k, v]) => [k, deepStripCommentKeys(v)])
    );
  }
  return obj;
}

function stableReplacer(key, value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return Object.fromEntries(
      Object.entries(value).sort(([a], [b]) => a.localeCompare(b))
    );
  }
  return value;
}

const DEMO_TOKENS = {
  '{{ENTERPRISE_SLUG}}':          'example-org',
  '{{ORG_SLUG}}':                 'example-org',
  '{{GOVERNANCE_REPO}}':          '.github-private',
  '{{OTLP_ENDPOINT}}':            'https://otel.example.internal/v1/traces',
  '{{OTLP_ENDPOINT_TOKEN}}':      'DEMO_TOKEN_NOT_FOR_PRODUCTION',
  '{{DEPLOY_ENV}}':               'production',
  '{{INTERNAL_MCP_URL}}':         'https://mcp.example.internal/standards',
  '{{GOVERNANCE_MARKETPLACE_URL}}': 'https://raw.githubusercontent.com/example-org/.github-private/main/.github/plugin/marketplace.json',
  '{{STANDARD_DEVELOPERS_TEAM}}': 'developers',
  '{{AI_PIONEERS_TEAM}}':         'ai-platform-pioneers',
};

function renderSource(src, tokenMap) {
  const substituted = substitute(src, tokenMap);
  const parsed = deepStripCommentKeys(parseJsonc(substituted));
  return JSON.stringify(parsed, stableReplacer, 2) + '\n';
}

// ─── Tests ───────────────────────────────────────────────────────────────────

test('managed-settings.source.jsonc parses as valid JSONC after substitution', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  assert.ok(typeof parsed === 'object', 'should be an object');
  assert.ok('permissions' in parsed, 'must have permissions key');
  assert.ok('sandbox' in parsed, 'must have sandbox key');
});

test('rendered output has no unresolved placeholders', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const rendered = renderSource(src, DEMO_TOKENS);
  const remaining = rendered.match(/\{\{[A-Z_]+\}\}/g);
  assert.equal(remaining, null, `Unresolved tokens in rendered output: ${remaining}`);
});

test('rendered output is valid JSON', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const rendered = renderSource(src, DEMO_TOKENS);
  assert.doesNotThrow(() => JSON.parse(rendered), 'rendered output must be valid JSON');
});

test('disableBypassPermissionsMode is "disable" and non-overridable', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  assert.equal(
    parsed.permissions?.disableBypassPermissionsMode,
    'disable',
    'disableBypassPermissionsMode must be "disable"'
  );
});

test('sandbox.enabled is true and sandbox.allowBypass is false in source', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  assert.equal(parsed.sandbox?.enabled, true, 'sandbox.enabled must be true');
  assert.equal(parsed.sandbox?.allowBypass, false, 'sandbox.allowBypass must be false');
});

test('telemetry.captureContent is false and lockCaptureContent is true', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  assert.equal(parsed.telemetry?.captureContent, false, 'captureContent must be false');
  assert.equal(parsed.telemetry?.lockCaptureContent, true, 'lockCaptureContent must be true');
});

test('allowedMcpServers has no http:// entries', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  for (const entry of (parsed.allowedMcpServers ?? [])) {
    if (entry.serverUrl) {
      assert.ok(!entry.serverUrl.startsWith('http://'), `MCP server uses http://: ${entry.serverUrl}`);
    }
  }
});

test('allowedMcpServers command entries have pinned versions', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  for (const entry of (parsed.allowedMcpServers ?? [])) {
    if (entry.args) {
      for (const arg of entry.args) {
        assert.ok(!/@latest$/.test(arg), `MCP server uses @latest: ${arg}`);
      }
    }
  }
});

test('strictKnownMarketplaces is true', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  assert.equal(parsed.strictKnownMarketplaces, true, 'strictKnownMarketplaces must be true');
});

test('team-mappings.source.jsonc parses with correct {"file.json":["team-slug"]} shape', () => {
  const src = readFileSync(path.join(ROOT, 'copilot', 'team-mappings.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  assert.ok(typeof parsed === 'object' && !Array.isArray(parsed), 'team-mappings must be a plain object');
  assert.ok(Object.keys(parsed).length >= 2, 'must have at least 2 team file entries');
  for (const [filePath, teams] of Object.entries(parsed)) {
    assert.ok(typeof filePath === 'string' && filePath.endsWith('.json'), `key must be a .json file path: ${filePath}`);
    assert.ok(Array.isArray(teams) && teams.length > 0, `value must be non-empty array of team slugs: ${filePath}`);
    assert.ok(teams.every(t => typeof t === 'string' && t.length > 0), `all team slugs must be non-empty strings: ${filePath}`);
  }
});

test('team settings files contain only overridable keys', () => {
  const NON_OVERRIDABLE = new Set([
    'permissions.disableBypassPermissionsMode',
    'sandbox', 'telemetry', 'remoteControl', 'strictKnownMarketplaces',
  ]);
  const teamFiles = ['copilot/teams/developers.source.jsonc', 'copilot/teams/ai-platform-pioneers.source.jsonc'];
  for (const relPath of teamFiles) {
    const src = readFileSync(path.join(ROOT, relPath), 'utf8');
    const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
    for (const topKey of Object.keys(parsed)) {
      assert.ok(!NON_OVERRIDABLE.has(topKey), `${relPath}: contains non-overridable top-level key "${topKey}"`);
    }
    // permissions, if present, must not contain disableBypassPermissionsMode
    if (parsed.permissions) {
      assert.ok(!('disableBypassPermissionsMode' in parsed.permissions),
        `${relPath}: permissions.disableBypassPermissionsMode is non-overridable`);
    }
  }
});

test('pioneers team uses unmanaged model and has additional MCP entry', () => {
  const src = readFileSync(path.join(ROOT, 'copilot/teams/ai-platform-pioneers.source.jsonc'), 'utf8');
  const parsed = parseJsonc(substitute(src, DEMO_TOKENS));
  assert.equal(parsed.permissions?.model, 'unmanaged', 'pioneers must use unmanaged model');
  assert.ok(Array.isArray(parsed.allowedMcpServers) && parsed.allowedMcpServers.length > 0,
    'pioneers must have additional allowedMcpServers');
  assert.ok(Array.isArray(parsed.enabledPlugins) && parsed.enabledPlugins.length > 0,
    'pioneers must have additive enabledPlugins');
});

test('generated managed-settings.json is valid JSON with required keys', () => {
  const content = readFileSync(path.join(ROOT, 'copilot', 'managed-settings.json'), 'utf8');
  const parsed = JSON.parse(content);
  assert.ok('permissions' in parsed, 'committed JSON has permissions key');
  assert.ok('sandbox' in parsed, 'committed JSON has sandbox key');
  assert.ok('telemetry' in parsed, 'committed JSON has telemetry key');
});
