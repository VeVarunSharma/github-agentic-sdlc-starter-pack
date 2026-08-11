import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const RENDERER = path.join(ROOT, 'scripts/render-managed-settings.mjs');
const SAFE_ARGS = [
  '--enterprise', 'example-enterprise',
  '--organization', 'example-org',
  '--governance-repo', '.github-private',
  '--governance-ref', '1111111111111111111111111111111111111111',
  '--otlp-endpoint', 'https://otel.example.internal/v1/traces',
  '--internal-mcp-url', 'https://mcp.example.internal/standards',
  '--pioneer-mcp-url', 'https://mcp.example.internal/pioneers',
  '--standard-team', 'developers',
  '--pioneer-team', 'ai-platform-pioneers',
];

test('validate-only accepts explicit safe deployment inputs without writing', () => {
  const output = execFileSync(process.execPath, [RENDERER, ...SAFE_ARGS, '--validate-only'], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.match(output, /no files were written/);
});

test('check mode proves committed generated JSON byte-matches', () => {
  const output = execFileSync(process.execPath, [RENDERER, '--check'], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.match(output, /managed-settings\.json is up to date/);
  assert.match(output, /team-mappings\.json is up to date/);
});

test('renderer rejects unknown arguments', () => {
  const result = spawnSync(process.execPath, [RENDERER, '--unknown'], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Unknown argument/);
});

test('renderer rejects invalid organization, URL, and mutable governance ref', () => {
  for (const args of [
    SAFE_ARGS.with(3, '../invalid'),
    SAFE_ARGS.with(9, 'http://otel.example.internal'),
    SAFE_ARGS.with(7, 'main'),
  ]) {
    const result = spawnSync(process.execPath, [RENDERER, ...args, '--validate-only'], {
      cwd: ROOT,
      encoding: 'utf8',
    });
    assert.notEqual(result.status, 0);
  }
});

test('generated managed settings use the complete official schema', () => {
  const managed = JSON.parse(readFileSync(path.join(ROOT, 'copilot/managed-settings.json'), 'utf8'));
  assert.deepEqual(Object.keys(managed.telemetry).sort(), [
    'captureContent',
    'enabled',
    'endpoint',
    'headers',
    'lockCaptureContent',
    'protocol',
    'resourceAttributes',
    'serviceName',
  ]);
  assert.equal(managed.permissions.disableBypassPermissionsMode, 'disable');
  assert.equal(managed.permissions.model.overridable, 'auto');
  assert.equal(managed.remoteControl.mode, 'requireSSO');
  assert.equal(managed.enabledPlugins['agentic-sdlc-standards@enterprise-standards'], true);
  assert.ok(Array.isArray(managed.strictKnownMarketplaces));
  assert.ok(Array.isArray(managed.allowedMcpServers.overridable));
});
