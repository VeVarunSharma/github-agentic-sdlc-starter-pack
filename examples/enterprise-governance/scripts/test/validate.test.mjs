import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const VALIDATOR = path.join(ROOT, 'scripts/validate-governance.mjs');

test('governance validator checks the complete overlay successfully', () => {
  const output = execFileSync(process.execPath, [VALIDATOR], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  assert.match(output, /Enterprise governance validation passed/);
});

test('overlay root is directly copyable without a nested .github-private folder', async () => {
  const { existsSync } = await import('node:fs');
  assert.equal(existsSync(path.join(ROOT, '.github-private')), false);
});
