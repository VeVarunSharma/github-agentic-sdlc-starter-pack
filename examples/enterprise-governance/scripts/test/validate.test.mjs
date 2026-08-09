// scripts/test/validate.test.mjs
// Tests for validate-governance.mjs logic (without side effects).
// Run via: node --test scripts/test/validate.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync, readFileSync } from 'node:fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');

// ─── Required files list (must match validate-governance.mjs) ────────────────

const REQUIRED_FILES = [
  'README.md', 'AGENTS.md', 'CODEOWNERS', 'package.json',
  'copilot/managed-settings.source.jsonc',
  'copilot/managed-settings.json',
  'copilot/team-mappings.source.jsonc',
  'copilot/team-mappings.json',
  'agents/sdlc-planner.agent.md',
  'agents/pr-reviewer.agent.md',
  'agents/governance-gardener.agent.md',
  '.github/agents/README.md',
  '.github/agents/test-candidate.agent.md',
  '.github/plugin/marketplace.json',
  '.github/workflows/overlay-validation.yml',
  'plugins/agentic-sdlc-standards/plugin.json',
  'scripts/render-managed-settings.mjs',
  'scripts/validate-governance.mjs',
  'scripts/bootstrap.sh',
  'docs/README.md',
  'docs/architecture/overview.md',
  'docs/architecture/mcp-threat-model.md',
  'docs/runbooks/rollout.md',
  'docs/runbooks/incident-rollback.md',
  'docs/runbooks/mdm-fallback.md',
  'docs/reference/settings-reference.md',
  'docs/reference/plugin-agent-lifecycle.md',
  'docs/reference/team-override-model.md',
  'docs/reference/verification-checklist.md',
  'docs/reference/client-support-matrix.md',
];

test('all required files exist', () => {
  const missing = REQUIRED_FILES.filter(rel => !existsSync(path.join(ROOT, rel)));
  assert.deepEqual(missing, [], `Missing required files: ${missing.join(', ')}`);
});

test('no nested .github-private directory inside overlay', () => {
  const nested = path.join(ROOT, '.github-private');
  assert.ok(!existsSync(nested), 'Must not have a nested .github-private directory');
});

test('scripts are present and non-empty', () => {
  for (const script of ['render-managed-settings.mjs', 'validate-governance.mjs', 'bootstrap.sh']) {
    const abs = path.join(ROOT, 'scripts', script);
    assert.ok(existsSync(abs), `Script missing: ${script}`);
    const content = readFileSync(abs, 'utf8');
    assert.ok(content.length > 100, `Script too short (may be empty): ${script}`);
  }
});
