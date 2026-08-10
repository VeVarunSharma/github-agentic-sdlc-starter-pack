#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import {
  existsSync,
  readFileSync,
  readdirSync,
  statSync,
} from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const errors = [];
const notes = [];

const REQUIRED_FILES = [
  'README.md',
  'AGENTS.md',
  'CODEOWNERS',
  'package.json',
  'package-lock.json',
  'config/render-inputs.json',
  'copilot/managed-settings.source.jsonc',
  'copilot/managed-settings.json',
  'copilot/team-mappings.source.jsonc',
  'copilot/team-mappings.json',
  'copilot/teams/developers.source.jsonc',
  'copilot/teams/developers.json',
  'copilot/teams/ai-platform-pioneers.source.jsonc',
  'copilot/teams/ai-platform-pioneers.json',
  'agents/sdlc-planner.agent.md',
  'agents/pr-reviewer.agent.md',
  'agents/governance-gardener.agent.md',
  '.github/agents/README.md',
  '.github/agents/test-candidate.agent.md',
  '.github/plugin/marketplace.json',
  '.github/rulesets/governance-branch-protect.json',
  '.github/workflows/overlay-validation.yml',
  'plugins/agentic-sdlc-standards/plugin.json',
  'plugins/agentic-sdlc-standards/agents/sdlc-planner.agent.md',
  'plugins/agentic-sdlc-standards/agents/pr-reviewer.agent.md',
  'plugins/agentic-sdlc-standards/skills/governance-validation/SKILL.md',
  'plugins/sdlc-pilot-tools/plugin.json',
  'plugins/sdlc-pilot-tools/skills/pilot-readiness/SKILL.md',
  'scripts/render-managed-settings.mjs',
  'scripts/validate-governance.mjs',
  'scripts/bootstrap-enterprise-governance.sh',
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
  'docs/reference/centralized-controls.md',
  'docs/reference/copilot-business.md',
];

const TOP_LEVEL_KEYS = new Set([
  'permissions',
  'enabledPlugins',
  'extraKnownMarketplaces',
  'strictKnownMarketplaces',
  'telemetry',
  'remoteControl',
  'allowedMcpServers',
  'deniedMcpServers',
  'sandbox',
]);

const DECLARED_TOKENS = new Set([
  '{{ENTERPRISE_SLUG}}',
  '{{ORG_SLUG}}',
  '{{GOVERNANCE_REPO}}',
  '{{GOVERNANCE_REF}}',
  '{{OTLP_ENDPOINT}}',
  '{{DEPLOY_ENV}}',
  '{{INTERNAL_MCP_URL}}',
  '{{PIONEER_MCP_URL}}',
  '{{STANDARD_DEVELOPERS_TEAM}}',
  '{{AI_PIONEERS_TEAM}}',
  '{{ENTERPRISE_GOVERNANCE_TEAM}}',
]);

const AGENT_TOOL_ALIASES = new Set([
  'read',
  'search',
  'edit',
  'execute',
  'agent',
  'web',
  'todo',
]);

function fail(message) {
  errors.push(message);
}

function walk(directory, predicate = () => true) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) return walk(target, predicate);
    return predicate(target) ? [target] : [];
  });
}

function relative(target) {
  return path.relative(ROOT, target).split(path.sep).join('/');
}

function parseJsonc(source) {
  let output = '';
  let index = 0;
  while (index < source.length) {
    if (source[index] === '"') {
      output += source[index++];
      while (index < source.length) {
        if (source[index] === '\\') {
          output += source[index] + source[index + 1];
          index += 2;
        } else {
          output += source[index];
          if (source[index++] === '"') break;
        }
      }
    } else if (source[index] === '/' && source[index + 1] === '/') {
      while (index < source.length && source[index] !== '\n') index++;
    } else if (source[index] === '/' && source[index + 1] === '*') {
      index += 2;
      while (index < source.length && !(source[index] === '*' && source[index + 1] === '/')) {
        index++;
      }
      index += 2;
    } else {
      output += source[index++];
    }
  }
  return JSON.parse(output.replace(/,(\s*[}\]])/g, '$1'));
}

function readJson(target) {
  try {
    return JSON.parse(readFileSync(target, 'utf8'));
  } catch (error) {
    fail(`${relative(target)}: invalid JSON (${error.message})`);
    return null;
  }
}

function assertExactKeys(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label}: expected an object`);
    return;
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    fail(`${label}: expected keys ${wanted.join(', ')}; found ${actual.join(', ')}`);
  }
}

function checkCommentCoverage(target) {
  const lines = readFileSync(target, 'utf8').split('\n');
  let count = 0;
  for (let index = 0; index < lines.length; index++) {
    if (!/^\s*"[^"]+"\s*:/.test(lines[index])) continue;
    count++;
    let previous = index - 1;
    while (previous >= 0 && lines[previous].trim() === '') previous--;
    if (previous < 0 || !lines[previous].trim().startsWith('//')) {
      fail(`${relative(target)}:${index + 1}: setting/subsetting lacks an adjacent comment`);
    }
  }
  notes.push(`${relative(target)}: ${count} documented properties`);
}

function checkMcpEntries(entries, label, allowLatest) {
  if (!Array.isArray(entries)) {
    fail(`${label}: expected an array`);
    return;
  }
  for (const [index, entry] of entries.entries()) {
    const keys = Object.keys(entry);
    if (keys.length !== 1 || !['serverUrl', 'serverCommand', 'serverName'].includes(keys[0])) {
      fail(`${label}[${index}]: must contain exactly one matcher`);
      continue;
    }
    if ('serverName' in entry) {
      fail(`${label}[${index}]: serverName is renameable and forbidden as a security matcher`);
    }
    if ('serverUrl' in entry) {
      if (typeof entry.serverUrl !== 'string' || !entry.serverUrl.startsWith('https://')) {
        fail(`${label}[${index}]: serverUrl must be an exact HTTPS URL`);
      }
      if (entry.serverUrl.includes('*')) fail(`${label}[${index}]: wildcard URL is forbidden`);
    }
    if ('serverCommand' in entry) {
      if (!Array.isArray(entry.serverCommand) || entry.serverCommand.length === 0) {
        fail(`${label}[${index}]: serverCommand must be a non-empty exact argument array`);
      } else if (!allowLatest && entry.serverCommand.some((part) => /@latest\b/.test(part))) {
        fail(`${label}[${index}]: mutable @latest command is forbidden in allowlists`);
      }
    }
  }
}

for (const required of REQUIRED_FILES) {
  if (!existsSync(path.join(ROOT, required))) fail(`${required}: required file is missing`);
}
const codeowners = readFileSync(path.join(ROOT, 'CODEOWNERS'), 'utf8');
for (const token of codeowners.match(/\{\{[A-Z_]+\}\}/g) ?? []) {
  if (token !== '{{ENTERPRISE_GOVERNANCE_TEAM}}') {
    fail(`CODEOWNERS: undeclared template token ${token}`);
  }
}

const sourceFiles = walk(ROOT, (target) => target.endsWith('.jsonc'));
for (const target of sourceFiles) {
  const source = readFileSync(target, 'utf8');
  try {
    parseJsonc(source.replace(/\{\{[A-Z_]+\}\}/g, 'example'));
  } catch (error) {
    fail(`${relative(target)}: invalid JSONC (${error.message})`);
  }
  checkCommentCoverage(target);
  for (const token of source.match(/\{\{[A-Z_]+\}\}/g) ?? []) {
    if (!DECLARED_TOKENS.has(token)) fail(`${relative(target)}: undeclared token ${token}`);
  }
  if (/(?:ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]+PRIVATE KEY-----|Bearer\s+[A-Za-z0-9._-]{20,})/i.test(source)) {
    fail(`${relative(target)}: secret-like value is forbidden`);
  }
}

for (const target of walk(ROOT, (file) => file.endsWith('.json'))) readJson(target);

const renderCheck = spawnSync(process.execPath, [
  path.join(ROOT, 'scripts/render-managed-settings.mjs'),
  '--check',
], { cwd: ROOT, encoding: 'utf8' });
if (renderCheck.status !== 0) {
  fail(`generated JSON drift: ${(renderCheck.stderr || renderCheck.stdout).trim()}`);
}

const managed = readJson(path.join(ROOT, 'copilot/managed-settings.json'));
const renderInputs = readJson(path.join(ROOT, 'config/render-inputs.json'));
if (managed) {
  const unknown = Object.keys(managed).filter((key) => !TOP_LEVEL_KEYS.has(key));
  const missing = [...TOP_LEVEL_KEYS].filter((key) => !(key in managed));
  if (unknown.length) fail(`managed-settings.json: unknown keys ${unknown.join(', ')}`);
  if (missing.length) fail(`managed-settings.json: missing keys ${missing.join(', ')}`);

  assertExactKeys(managed.permissions, ['disableBypassPermissionsMode', 'model'], 'permissions');
  if (managed.permissions?.disableBypassPermissionsMode !== 'disable') {
    fail('permissions.disableBypassPermissionsMode: secure floor must be "disable"');
  }
  assertExactKeys(managed.permissions?.model, ['overridable'], 'permissions.model');
  if (managed.permissions?.model?.overridable !== 'auto') {
    fail('permissions.model.overridable: baseline must be "auto"');
  }

  if (!managed.enabledPlugins || Array.isArray(managed.enabledPlugins)) {
    fail('enabledPlugins: expected PLUGIN@MARKETPLACE boolean map');
  } else if (managed.enabledPlugins['agentic-sdlc-standards@enterprise-standards'] !== true) {
    fail('enabledPlugins: required enterprise standards plugin is not enabled');
  }

  for (const [name, marketplace] of Object.entries(managed.extraKnownMarketplaces ?? {})) {
    assertExactKeys(marketplace, ['source'], `extraKnownMarketplaces.${name}`);
    if (marketplace.source?.source !== 'github' ||
        !/^[^/]+\/[^/]+$/.test(marketplace.source?.repo ?? '') ||
        !/^[0-9a-f]{40}$/i.test(marketplace.source?.ref ?? '')) {
      fail(`extraKnownMarketplaces.${name}: expected pinned GitHub repo source`);
    }
  }
  if (!Array.isArray(managed.strictKnownMarketplaces) || managed.strictKnownMarketplaces.length !== 3) {
    fail('strictKnownMarketplaces: expected exactly the three reviewed pinned sources');
  } else {
    for (const [index, source] of managed.strictKnownMarketplaces.entries()) {
      assertExactKeys(source, ['source', 'repo', 'ref'], `strictKnownMarketplaces[${index}]`);
      if (source.source !== 'github' || !/^[0-9a-f]{40}$/i.test(source.ref ?? '')) {
        fail(`strictKnownMarketplaces[${index}]: expected pinned GitHub source`);
      }
    }
  }

  assertExactKeys(managed.telemetry, [
    'enabled',
    'endpoint',
    'protocol',
    'captureContent',
    'lockCaptureContent',
    'serviceName',
    'resourceAttributes',
    'headers',
  ], 'telemetry');
  if (managed.telemetry?.enabled !== false ||
      managed.telemetry?.captureContent !== false ||
      managed.telemetry?.lockCaptureContent !== true ||
      Object.keys(managed.telemetry?.headers ?? {}).length !== 0) {
    fail('telemetry: baseline must stay disabled, content-locked off, with empty headers');
  }

  assertExactKeys(managed.remoteControl, ['mode', 'githubDotComOrganizations'], 'remoteControl');
  if (managed.remoteControl?.mode !== 'requireSSO' ||
      !Array.isArray(managed.remoteControl?.githubDotComOrganizations) ||
      managed.remoteControl.githubDotComOrganizations.length !== 1) {
    fail('remoteControl: requireSSO with one configured organization is required');
  }

  assertExactKeys(managed.allowedMcpServers, ['overridable'], 'allowedMcpServers');
  checkMcpEntries(managed.allowedMcpServers?.overridable, 'allowedMcpServers.overridable', false);
  checkMcpEntries(managed.deniedMcpServers, 'deniedMcpServers', true);
  if (!(managed.deniedMcpServers ?? []).some((entry) =>
    entry.serverCommand?.some((part) => /@latest\b/.test(part)))) {
    fail('deniedMcpServers: expected an exact mutable-command deny example');
  }

  assertExactKeys(managed.sandbox, [
    'enabled',
    'allowBypass',
    'addCurrentWorkingDirectory',
    'sandboxMcpServers',
    'sandboxLspServers',
    'gitAuth',
    'ghAuth',
    'allowDevToolAccess',
    'userPolicy',
  ], 'sandbox');
  assertExactKeys(managed.sandbox?.userPolicy, ['filesystem', 'network', 'seatbelt'], 'sandbox.userPolicy');
  assertExactKeys(managed.sandbox?.userPolicy?.filesystem, [
    'readwritePaths',
    'readonlyPaths',
    'deniedPaths',
  ], 'sandbox.userPolicy.filesystem');
  assertExactKeys(managed.sandbox?.userPolicy?.network, [
    'allowOutbound',
    'allowLocalNetwork',
  ], 'sandbox.userPolicy.network');
  assertExactKeys(managed.sandbox?.userPolicy?.seatbelt, ['keychainAccess'], 'sandbox.userPolicy.seatbelt');
  if (managed.sandbox?.enabled !== true ||
      managed.sandbox?.allowBypass !== false ||
      managed.sandbox?.sandboxMcpServers !== true ||
      managed.sandbox?.sandboxLspServers !== true ||
      managed.sandbox?.gitAuth !== true ||
      managed.sandbox?.ghAuth !== true ||
      managed.sandbox?.allowDevToolAccess !== true ||
      managed.sandbox?.userPolicy?.network?.allowOutbound !== true ||
      managed.sandbox?.userPolicy?.network?.allowLocalNetwork !== false ||
      managed.sandbox?.userPolicy?.seatbelt?.keychainAccess !== false) {
    fail('sandbox: baseline capability-direction values do not match the required posture');
  }
  for (const key of ['readwritePaths', 'readonlyPaths', 'deniedPaths']) {
    if (!Array.isArray(managed.sandbox?.userPolicy?.filesystem?.[key]) ||
        managed.sandbox.userPolicy.filesystem[key].length !== 0) {
      fail(`sandbox.userPolicy.filesystem.${key}: portable baseline must be an empty array`);
    }
  }
}

const mappings = readJson(path.join(ROOT, 'copilot/team-mappings.json'));
for (const [filename, teams] of Object.entries(mappings ?? {})) {
  if (filename.includes('/') || !filename.endsWith('.json')) {
    fail(`team-mappings.json: ${filename} must be a filename beneath copilot/teams`);
  }
  if (!Array.isArray(teams) || teams.length === 0 || teams.some((team) => !/^[A-Za-z0-9][A-Za-z0-9-]*$/.test(team))) {
    fail(`team-mappings.json: ${filename} must map to non-empty team slugs`);
  }
  const teamPolicy = readJson(path.join(ROOT, 'copilot/teams', filename));
  if (!teamPolicy) continue;
  const allowedKeys = new Set([
    'model',
    'allowedMcpServers',
    'deniedMcpServers',
    'enabledPlugins',
    'extraKnownMarketplaces',
  ]);
  for (const key of Object.keys(teamPolicy)) {
    if (!allowedKeys.has(key)) fail(`copilot/teams/${filename}: non-overridable key ${key}`);
  }
  if (teamPolicy.allowedMcpServers) {
    checkMcpEntries(teamPolicy.allowedMcpServers, `copilot/teams/${filename}.allowedMcpServers`, false);
  }
}
const pioneer = readJson(path.join(ROOT, 'copilot/teams/ai-platform-pioneers.json'));
if (pioneer?.model !== 'unmanaged' ||
    !Array.isArray(pioneer?.allowedMcpServers) ||
    pioneer?.enabledPlugins?.['sdlc-pilot-tools@enterprise-standards'] !== true) {
  fail('ai-platform-pioneers.json: expected unmanaged model, MCP specialization, and additive plugin');
} else {
  const serializedPioneer = new Set(pioneer.allowedMcpServers.map((entry) => JSON.stringify(entry)));
  for (const baseline of managed?.allowedMcpServers?.overridable ?? []) {
    if (!serializedPioneer.has(JSON.stringify(baseline))) {
      fail('ai-platform-pioneers.json: specialization must repeat every enterprise MCP baseline matcher');
    }
  }
  if (!pioneer.allowedMcpServers.some((entry) => entry.serverUrl === renderInputs?.pioneerMcpUrl)) {
    fail('ai-platform-pioneers.json: exact pioneer MCP endpoint is missing');
  }
}

const marketplace = readJson(path.join(ROOT, '.github/plugin/marketplace.json'));
assertExactKeys(marketplace, ['name', 'owner', 'metadata', 'plugins'], 'marketplace.json');
const marketplaceNames = new Set();
for (const [index, entry] of (marketplace?.plugins ?? []).entries()) {
  assertExactKeys(entry, ['name', 'description', 'version', 'source'], `marketplace.json.plugins[${index}]`);
  marketplaceNames.add(entry.name);
  const source = path.resolve(ROOT, entry.source);
  if (!source.startsWith(`${path.join(ROOT, 'plugins')}${path.sep}`) ||
      !existsSync(path.join(source, 'plugin.json'))) {
    fail(`marketplace.json.plugins[${index}]: source must resolve to a contained plugin`);
  }
}
for (const ref of Object.keys(managed?.enabledPlugins ?? {})) {
  const [pluginName, marketplaceName] = ref.split('@');
  if (marketplaceName !== marketplace?.name || !marketplaceNames.has(pluginName)) {
    fail(`enabledPlugins: ${ref} does not resolve in the contained marketplace`);
  }
}

for (const target of walk(path.join(ROOT, 'plugins'), (file) => file.endsWith('plugin.json'))) {
  const manifest = readJson(target);
  if (!/^[a-z0-9-]{1,64}$/.test(manifest?.name ?? '')) {
    fail(`${relative(target)}: plugin name must be kebab-case`);
  }
  for (const field of ['agents', 'skills']) {
    for (const configured of [manifest?.[field]].flat().filter(Boolean)) {
      const resolved = path.resolve(path.dirname(target), configured);
      if (!resolved.startsWith(`${path.dirname(target)}${path.sep}`) || !existsSync(resolved)) {
        fail(`${relative(target)}: ${field} path escapes or does not exist (${configured})`);
      }
    }
  }
}

for (const target of walk(ROOT, (file) => file.endsWith('.agent.md'))) {
  const content = readFileSync(target, 'utf8');
  const frontmatter = content.match(/(?:^|\n)---\n([\s\S]*?)\n---/);
  if (!frontmatter || !/^description:\s*.+$/m.test(frontmatter[1])) {
    fail(`${relative(target)}: agent requires description frontmatter`);
  }
  const tools = frontmatter?.[1]?.match(/^tools:\s*\[(.*)]$/m)?.[1]
    .split(',')
    .map((tool) => tool.trim().replaceAll('"', ''))
    .filter(Boolean) ?? [];
  for (const tool of tools) {
    if (!AGENT_TOOL_ALIASES.has(tool) && !tool.includes('/')) {
      fail(`${relative(target)}: unsupported tool alias ${tool}`);
    }
  }
}

for (const target of walk(path.join(ROOT, '.github/workflows'), (file) => /\.ya?ml$/.test(file))) {
  for (const [index, line] of readFileSync(target, 'utf8').split('\n').entries()) {
    const action = line.match(/^\s*(?:-\s*)?uses:\s*([^#\s]+)/)?.[1];
    if (action && !action.startsWith('./') && !/@[0-9a-f]{40}$/i.test(action)) {
      fail(`${relative(target)}:${index + 1}: action must use a full commit SHA`);
    }
  }
}

for (const target of walk(ROOT, (file) => file.endsWith('.md'))) {
  const content = readFileSync(target, 'utf8');
  for (const match of content.matchAll(/!?\[[^\]]*]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)) {
    const link = match[1];
    if (/^(https?:|mailto:|tel:|#)/.test(link)) continue;
    const [pathname] = link.split('#', 1);
    if (!existsSync(path.resolve(path.dirname(target), decodeURIComponent(pathname)))) {
      fail(`${relative(target)}: broken relative link ${link}`);
    }
  }
}

for (const target of walk(ROOT, (file) => /\.(?:json|md|mjs|sh|yml|jsonc)$/.test(file))) {
  const content = readFileSync(target, 'utf8');
  for (const token of content.match(/\{\{[A-Z_]+\}\}/g) ?? []) {
    if (!DECLARED_TOKENS.has(token)) fail(`${relative(target)}: undeclared template token ${token}`);
    if (target.endsWith('.json')) fail(`${relative(target)}: generated strict JSON contains ${token}`);
  }
}

if (errors.length) {
  for (const error of errors) process.stderr.write(`ERROR: ${error}\n`);
  process.stderr.write(`${errors.length} governance validation failure(s)\n`);
  process.exitCode = 1;
} else {
  process.stdout.write(`Enterprise governance validation passed (${notes.join('; ')}).\n`);
}
