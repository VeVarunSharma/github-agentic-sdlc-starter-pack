import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const BOOTSTRAP = path.join(ROOT, 'scripts/bootstrap-enterprise-governance.sh');
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

test('bootstrap help documents dry-run, apply, and exact confirmation', () => {
  const output = execFileSync('bash', [BOOTSTRAP, '--help'], { encoding: 'utf8' });
  assert.match(output, /--apply/);
  assert.match(output, /--confirm/);
  assert.match(output, /never creates an enterprise/i);
});

test('bootstrap rejects missing and unknown arguments', () => {
  for (const args of [[], ['--unknown']]) {
    const result = spawnSync('bash', [BOOTSTRAP, ...args], { encoding: 'utf8' });
    assert.notEqual(result.status, 0);
  }
});

test('dry-run validates locally and executes no gh command', () => {
  const output = execFileSync('bash', [BOOTSTRAP, ...SAFE_ARGS], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.match(output, /DRY-RUN: no GitHub mutation executed/);
});

test('apply is rejected before gh access without exact confirmation', () => {
  const result = spawnSync('bash', [BOOTSTRAP, ...SAFE_ARGS, '--apply'], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /--confirm must exactly equal/);
});

test('bootstrap avoids dynamic shell evaluation and embedded secrets', () => {
  const source = readFileSync(BOOTSTRAP, 'utf8');
  assert.doesNotMatch(source, /\beval\b/);
  assert.doesNotMatch(source, /(?:ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|Bearer\s+[A-Za-z0-9._-]{20,})/);
  assert.match(source, /APPLY=false/);
});
