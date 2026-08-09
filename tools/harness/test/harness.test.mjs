import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  parseHookPayload,
  shouldValidate,
  validationResult,
} from '../src/hook.mjs';
import {
  checkMcp,
  checkRequiredCheckContracts,
  parseFrontmatter,
  requiredCheckNames,
  validateRepository,
} from '../src/validate.mjs';

const packageRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
const repoRoot = resolve(packageRoot, '../..');
const fixtureRoot = resolve(packageRoot, 'test/fixtures/hooks');

async function fixture(name) {
  return readFile(resolve(fixtureRoot, name), 'utf8');
}

test('frontmatter parses current agent aliases', () => {
  const parsed = parseFrontmatter('---\ndescription: "test"\ntools: ["read", "search"]\n---\n');
  assert.deepEqual(parsed.tools, ['read', 'search']);
});

test('hook fixtures distinguish relevant and irrelevant tools', async () => {
  assert.equal(shouldValidate(parseHookPayload(await fixture('irrelevant.json'))), false);
  assert.equal(shouldValidate(parseHookPayload(await fixture('relevant.json'))), true);
  assert.equal(
    shouldValidate({
      ...parseHookPayload(await fixture('relevant.json')),
      cwd: repoRoot,
      toolArgs: { path: resolve(repoRoot, 'docs/README.md') },
    }),
    true,
  );
});

test('hook fixture rejects non-object input', async () => {
  const malformed = await fixture('malformed.json');
  assert.throws(() => parseHookPayload(malformed), /JSON object/);
});

test('postToolUse failure adds context without a blocking exit code', async () => {
  const payload = parseHookPayload(await fixture('relevant.json'));
  const result = validationResult(payload, () => ({
    status: 1,
    stdout: '',
    stderr: 'fixture failure',
  }));
  assert.equal(result.exitCode, 0);
  assert.match(result.output.additionalContext, /fixture failure/);
  assert.equal(result.output.decision, undefined);
});

test('agentStop failure returns a real block decision', () => {
  const result = validationResult(
    {
      sessionId: 'fixture',
      timestamp: 0,
      cwd: repoRoot,
      transcriptPath: '/tmp/transcript.jsonl',
      stopReason: 'end_turn',
      stop_hook_active: false,
    },
    () => ({
      status: 1,
      stdout: '',
      stderr: 'stop fixture failure',
    }),
  );
  assert.equal(result.exitCode, 0);
  assert.equal(result.output.decision, 'block');
  assert.match(result.output.reason, /stop fixture failure/);
});

test('MCP validation reports malformed JSON without throwing', async (t) => {
  const root = await mkdtemp(resolve(tmpdir(), 'harness-mcp-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(resolve(root, '.github/mcp'), { recursive: true });
  await mkdir(resolve(root, '.vscode'), { recursive: true });
  await writeFile(resolve(root, '.github/mcp/mcp.json'), '{ invalid json\n');
  await writeFile(resolve(root, '.vscode/mcp.json'), '{"servers":{} }\n');
  const errors = [];
  checkMcp(root, errors);
  assert.equal(errors.length, 1);
  assert.match(errors[0], /invalid strict JSON/);
});

test('required check contract follows the CI job display name', async (t) => {
  const root = await mkdtemp(resolve(tmpdir(), 'harness-checks-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(resolve(root, '.github/workflows'), { recursive: true });
  await mkdir(resolve(root, '.github/rulesets'), { recursive: true });
  await mkdir(resolve(root, 'docs'), { recursive: true });
  for (const path of [
    '.github/workflows/ci.yml',
    '.github/workflows/codeql.yml',
    '.github/workflows/apm-audit.yml',
    '.github/workflows/dependency-review.yml',
    '.github/rulesets/main-branch-evaluate.json',
    '.github/rulesets/main-branch-enforce.json',
    '.github/rulesets/README.md',
    'docs/repo-settings-checklist.md',
  ]) {
    await writeFile(resolve(root, path), await readFile(resolve(repoRoot, path), 'utf8'));
  }
  for (const path of [
    '.github/rulesets/main-branch-evaluate.json',
    '.github/rulesets/main-branch-enforce.json',
    '.github/rulesets/README.md',
    'docs/repo-settings-checklist.md',
  ]) {
    const target = resolve(root, path);
    await writeFile(
      target,
      (await readFile(target, 'utf8')).replace(
        'repository — harness + workflows + shell + JSON',
        'repository — stale contract',
      ),
    );
  }
  const errors = [];
  checkRequiredCheckContracts(root, errors);
  assert.equal(errors.length, 6);
  assert.ok(errors.every((error) => error.includes('repository —')));
});

test('required check contract derives every current workflow context', () => {
  assert.deepEqual(requiredCheckNames(repoRoot), [
    'app — lint + tests + audit',
    'terraform — fmt + validate (infra/bootstrap)',
    'terraform — fmt + validate (infra/app)',
    'terraform — fmt + validate (examples/azure-container-apps/infra/app)',
    'docker — lint + scan + health smoke',
    'repository — harness + workflows + shell + JSON',
    'Analyze (javascript-typescript)',
    'apm install + audit',
    'Review dependency changes',
  ]);
});

test('full repository satisfies the harness contract', () => {
  assert.deepEqual(validateRepository(repoRoot), []);
});
