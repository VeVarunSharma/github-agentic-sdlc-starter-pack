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
import { checkMcp, parseFrontmatter, validateRepository } from '../src/validate.mjs';

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
});

test('hook fixture rejects non-object input', async () => {
  const malformed = await fixture('malformed.json');
  assert.throws(() => parseHookPayload(malformed), /JSON object/);
});

test('hook emits compact context and exit 2 when validation fails', async () => {
  const payload = parseHookPayload(await fixture('relevant.json'));
  const result = validationResult(payload, () => ({
    status: 1,
    stdout: '',
    stderr: 'fixture failure',
  }));
  assert.equal(result.exitCode, 2);
  assert.match(result.output.additionalContext, /fixture failure/);
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

test('full repository satisfies the harness contract', () => {
  assert.deepEqual(validateRepository(repoRoot), []);
});
