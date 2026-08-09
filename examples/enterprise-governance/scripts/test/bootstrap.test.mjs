// scripts/test/bootstrap.test.mjs
// Tests for bootstrap.sh — verifies no-mutation behavior in dry-run mode.
// Run via: node --test scripts/test/bootstrap.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
const BOOTSTRAP = path.join(ROOT, 'scripts', 'bootstrap.sh');

test('bootstrap.sh exists and is non-empty', () => {
  assert.ok(existsSync(BOOTSTRAP), 'bootstrap.sh must exist');
  const content = readFileSync(BOOTSTRAP, 'utf8');
  assert.ok(content.length > 200, 'bootstrap.sh must have substantial content');
});

test('bootstrap.sh --help exits 0 and prints usage', () => {
  const result = execFileSync('bash', [BOOTSTRAP, '--help'], {
    encoding: 'utf8',
    env: { ...process.env },
  });
  assert.ok(result.includes('USAGE'), 'help output must contain USAGE');
  assert.ok(result.includes('--apply'), 'help must mention --apply flag');
  assert.ok(result.includes('--enterprise'), 'help must mention --enterprise flag');
});

test('bootstrap.sh dry-run requires --enterprise and --organization', () => {
  let threw = false;
  try {
    execFileSync('bash', [BOOTSTRAP], {
      encoding: 'utf8',
      env: { ...process.env },
      stdio: 'pipe',
    });
  } catch (err) {
    threw = true;
    // Should exit non-zero and print error about missing args
    assert.ok(
      err.stderr?.includes('required') || err.stdout?.includes('required'),
      'must print "required" when args missing'
    );
  }
  assert.ok(threw, 'bootstrap.sh must exit non-zero when required args are missing');
});

test('bootstrap.sh dry-run with valid args does not mutate (no --apply)', () => {
  // Run in dry-run mode — must exit 0 and print DRY-RUN markers, not execute API calls
  // We use fake slugs that are valid format but won't resolve to real resources
  const result = execFileSync(
    'bash',
    [
      BOOTSTRAP,
      '--enterprise', 'example-corp',
      '--organization', 'example-org',
      '--governance-repo', '.github-private',
    ],
    {
      encoding: 'utf8',
      env: { ...process.env },
      // Dry-run may fail at Node validation step (render) if packages not installed.
      // We check the output for DRY-RUN markers at minimum.
      timeout: 30000,
    }
  );
  assert.ok(
    result.includes('DRY-RUN') || result.includes('dry-run'),
    'dry-run output must contain DRY-RUN marker'
  );
  // Must NOT contain "gh api -X POST" as executed (only printed)
  assert.ok(
    !result.includes('Creating private repository'),
    'dry-run must not actually create a repository'
  );
});

test('bootstrap.sh does not contain --apply in default invocation', () => {
  const content = readFileSync(BOOTSTRAP, 'utf8');
  // Verify dry-run is the default (APPLY=false must appear)
  assert.ok(content.includes('APPLY=false'), 'dry-run must be default (APPLY=false)');
  assert.ok(content.includes('--apply'), 'must have --apply flag');
});
