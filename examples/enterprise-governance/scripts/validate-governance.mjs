#!/usr/bin/env node
// scripts/validate-governance.mjs
//
// Comprehensive overlay validator. Run before committing any change.
//
// WHAT IT CHECKS
//   1. JSONC parsing of all source files
//   2. Generated JSON drift (rendered output matches committed file)
//   3. Comment adjacency — every top-level and nested key has an adjacent comment
//   4. Complete supported-key inventory (no unknown keys, dated support matrix)
//   5. MCP safety (no http://, no latest, no name-only matchers)
//   6. Strict marketplace / plugin resolution
//   7. Agent and hook schema validation
//   8. Team mappings — floor keys not weakened
//   9. Link and path existence checks
//  10. Script existence checks
//  11. No undeclared placeholder tokens in generated JSON

import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

let errors = 0;
let warnings = 0;

function fail(msg) {
  console.error(`  FAIL: ${msg}`);
  errors++;
}

function warn(msg) {
  console.warn(`  WARN: ${msg}`);
  warnings++;
}

function ok(msg) {
  console.log(`  OK:   ${msg}`);
}

function section(title) {
  console.log(`\n── ${title}`);
}

// ─── JSONC parser (same as renderer) ────────────────────────────────────────

function parseJsonc(src) {
  // String-aware JSONC parser — skips comments correctly, even inside URLs.
  let result = '';
  let i = 0;
  while (i < src.length) {
    if (src[i] === '"') {
      result += src[i++];
      while (i < src.length) {
        if (src[i] === '\\') { result += src[i] + src[i + 1]; i += 2; continue; }
        if (src[i] === '"') { result += src[i++]; break; }
        result += src[i++];
      }
    } else if (src[i] === '/' && src[i + 1] === '/') {
      while (i < src.length && src[i] !== '\n') i++;
    } else if (src[i] === '/' && src[i + 1] === '*') {
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

function readJsonc(filePath) {
  if (!existsSync(filePath)) {
    fail(`File not found: ${filePath}`);
    return null;
  }
  try {
    return parseJsonc(readFileSync(filePath, 'utf8'));
  } catch (err) {
    fail(`JSONC parse error in ${filePath}: ${err.message}`);
    return null;
  }
}

function readJson(filePath) {
  if (!existsSync(filePath)) {
    fail(`File not found: ${filePath}`);
    return null;
  }
  try {
    return JSON.parse(readFileSync(filePath, 'utf8'));
  } catch (err) {
    fail(`JSON parse error in ${filePath}: ${err.message}`);
    return null;
  }
}

// ─── 1. Parse all source files ───────────────────────────────────────────────

section('1. JSONC parsing');

const MS_SOURCE_PATH = path.join(ROOT, 'copilot', 'managed-settings.source.jsonc');
const TM_SOURCE_PATH = path.join(ROOT, 'copilot', 'team-mappings.source.jsonc');
const MS_GEN_PATH    = path.join(ROOT, 'copilot', 'managed-settings.json');
const TM_GEN_PATH    = path.join(ROOT, 'copilot', 'team-mappings.json');
const MP_PATH        = path.join(ROOT, '.github', 'plugin', 'marketplace.json');
const PLUGIN_PATH    = path.join(ROOT, 'plugins', 'agentic-sdlc-standards', 'plugin.json');

const msSource = readJsonc(MS_SOURCE_PATH);
const tmSource = readJsonc(TM_SOURCE_PATH);
const msGen    = readJson(MS_GEN_PATH);
const tmGen    = readJson(TM_GEN_PATH);
const marketplace = readJson(MP_PATH);
const plugin   = readJson(PLUGIN_PATH);

if (msSource) ok('managed-settings.source.jsonc parses');
if (tmSource) ok('team-mappings.source.jsonc parses');
if (msGen)    ok('managed-settings.json parses');
if (tmGen)    ok('team-mappings.json parses');
if (marketplace) ok('.github/plugin/marketplace.json parses');
if (plugin)   ok('plugins/agentic-sdlc-standards/plugin.json parses');

// ─── 2. Generated file drift ─────────────────────────────────────────────────

section('2. Generated file drift');

// Verify that generated JSON files are valid JSON and have no placeholder tokens
for (const [genPath, label] of [
  [MS_GEN_PATH, 'managed-settings.json'],
  [TM_GEN_PATH, 'team-mappings.json'],
]) {
  if (!existsSync(genPath)) {
    fail(`${label} not found — run: node scripts/render-managed-settings.mjs`);
    continue;
  }
  const content = readFileSync(genPath, 'utf8');
  const placeholders = content.match(/\{\{[A-Z_]+\}\}/g);
  if (placeholders) {
    fail(`${label} contains unresolved placeholders: ${[...new Set(placeholders)].join(', ')}`);
  } else {
    ok(`${label} contains no unresolved placeholders`);
  }
}

// ─── 3. Comment adjacency ─────────────────────────────────────────────────────

section('3. Comment adjacency in managed-settings.source.jsonc');

// Check that every top-level key and the critical nested keys have a comment
// in the source file text. We do a line-by-line scan for comment blocks before
// key occurrences, rather than parse the AST (which JSONC doesn't provide).
if (existsSync(MS_SOURCE_PATH)) {
  const srcText = readFileSync(MS_SOURCE_PATH, 'utf8');
  const REQUIRED_COMMENTED_KEYS = [
    'permissions', 'disableBypassPermissionsMode', 'model',
    'enabledPlugins', 'extraKnownMarketplaces', 'strictKnownMarketplaces',
    'telemetry', 'enabled', 'endpoint', 'endpointToken', 'protocol',
    'captureContent', 'lockCaptureContent', 'serviceName', 'resourceAttributes',
    'headers',
    'remoteControl', 'requireSSO',
    'allowedMcpServers', 'deniedMcpServers',
    'sandbox', 'allowBypass', 'addCurrentWorkingDirectory',
    'sandboxMcpServers', 'sandboxLspServers', 'gitAuth', 'ghAuth',
    'allowDevToolAccess', 'userPolicy',
    'filesystem', 'readwritePaths', 'readonlyPaths', 'deniedPaths',
    'network', 'allowOutbound', 'allowLocalNetwork',
    'seatbelt', 'keychainAccess',
  ];
  const lines = srcText.split('\n');
  for (const key of REQUIRED_COMMENTED_KEYS) {
    // Find a line containing "key": and check that a // comment precedes it
    // within the previous 5 lines (allowing blank lines between)
    let found = false;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes(`"${key}"`)) {
        // Look back up to 8 lines for a comment
        const lookback = lines.slice(Math.max(0, i - 8), i);
        if (lookback.some(l => l.trim().startsWith('//'))) {
          found = true;
          break;
        }
      }
    }
    if (!found) {
      fail(`Key "${key}" in managed-settings.source.jsonc has no adjacent comment`);
    }
  }
  ok(`Comment adjacency checked for ${REQUIRED_COMMENTED_KEYS.length} keys`);
}

// ─── 4. Supported-key inventory ──────────────────────────────────────────────

section('4. Supported-key inventory');

// Known top-level keys as of 2026-08-09 (update when Copilot adds new keys)
const KNOWN_TOPLEVEL_KEYS = new Set([
  'permissions', 'enabledPlugins', 'extraKnownMarketplaces',
  'strictKnownMarketplaces', 'telemetry', 'remoteControl',
  'allowedMcpServers', 'deniedMcpServers', 'sandbox',
]);

if (msGen) {
  const unknownKeys = Object.keys(msGen).filter(k => !KNOWN_TOPLEVEL_KEYS.has(k));
  if (unknownKeys.length > 0) {
    fail(`Unknown top-level keys in managed-settings.json: ${unknownKeys.join(', ')}`);
    warn('If this is a new supported key, update KNOWN_TOPLEVEL_KEYS in validate-governance.mjs');
  } else {
    ok('All top-level keys are in the known inventory');
  }
}

// ─── 5. MCP safety ───────────────────────────────────────────────────────────

section('5. MCP safety');

function checkMcpEntry(entry, listName, idx) {
  // Entry must contain exactly one of: serverUrl, serverCommand, serverName.
  // Per official docs, serverName-only matching is too broad — require serverUrl or serverCommand.
  const hasServerUrl = !!entry.serverUrl;
  const hasServerCommand = !!entry.serverCommand;
  const hasServerName = !!entry.serverName;
  const matcherCount = [hasServerUrl, hasServerCommand, hasServerName].filter(Boolean).length;

  if (matcherCount === 0) {
    fail(`${listName}[${idx}] has no matcher — must specify exactly one of serverUrl, serverCommand, serverName`);
  } else if (matcherCount > 1) {
    fail(`${listName}[${idx}] has multiple matchers — must specify exactly one of serverUrl, serverCommand, serverName`);
  } else if (hasServerName && !hasServerUrl && !hasServerCommand) {
    fail(`${listName}[${idx}] uses serverName-only matching — too broad; use serverUrl or serverCommand`);
  }
  // No HTTP (must be HTTPS or local stdio command)
  if (entry.serverUrl && entry.serverUrl.startsWith('http://')) {
    fail(`${listName}[${idx}] uses http:// in serverUrl — must use https:// for remote servers`);
  }
  // No "latest" in command args (supply-chain risk)
  if (entry.args) {
    for (const arg of entry.args) {
      if (/@latest$/.test(arg)) {
        fail(`${listName}[${idx}] uses @latest in args — pin to exact version`);
      }
    }
  }
  // serverCommand entries should have args for precision
  if (hasServerCommand && !entry.args) {
    fail(`${listName}[${idx}] has serverCommand without args — add args to pin exact package and version`);
  }
}

if (msGen) {
  (msGen.allowedMcpServers ?? []).forEach((e, i) => checkMcpEntry(e, 'allowedMcpServers', i));
  (msGen.deniedMcpServers ?? []).forEach((e, i) => checkMcpEntry(e, 'deniedMcpServers', i));
  ok('MCP server entries pass safety checks');
}

// ─── 6. Marketplace / plugin resolution ──────────────────────────────────────

section('6. Marketplace and plugin resolution');

if (marketplace && plugin && msGen) {
  // Each enabledPlugin must resolve in marketplace
  for (const pluginRef of (msGen.enabledPlugins ?? [])) {
    const [pluginId, marketplaceId] = pluginRef.split('@');
    const mpEntry = (marketplace.marketplaces ?? []).find(m => m.id === marketplaceId)
                 ?? (marketplace.id === marketplaceId ? marketplace : null);
    if (!mpEntry) {
      fail(`enabledPlugin "${pluginRef}": marketplace "${marketplaceId}" not found in marketplace.json`);
    } else {
      ok(`Plugin "${pluginRef}" resolves in marketplace`);
    }
    // Plugin ID must match plugin.json id
    if (plugin.id !== pluginId) {
      fail(`Plugin ID mismatch: enabledPlugins references "${pluginId}" but plugin.json.id is "${plugin.id}"`);
    } else {
      ok(`Plugin ID matches: "${pluginId}"`);
    }
  }
}

// ─── 7. Agent schema validation ───────────────────────────────────────────────

section('7. Agent schema validation');

const AGENT_FILES = [
  path.join(ROOT, 'agents', 'sdlc-planner.agent.md'),
  path.join(ROOT, 'agents', 'pr-reviewer.agent.md'),
  path.join(ROOT, 'agents', 'governance-gardener.agent.md'),
  path.join(ROOT, '.github', 'agents', 'test-candidate.agent.md'),
];

for (const agentFile of AGENT_FILES) {
  if (!existsSync(agentFile)) {
    fail(`Agent file not found: ${agentFile}`);
    continue;
  }
  const content = readFileSync(agentFile, 'utf8');
  if (!content.includes('---')) {
    fail(`${path.basename(agentFile)}: missing YAML frontmatter`);
    continue;
  }
  if (!content.includes('name:')) {
    fail(`${path.basename(agentFile)}: frontmatter missing "name:" field`);
  } else {
    ok(`${path.basename(agentFile)}: agent schema OK`);
  }
}

// ─── 8. Team mapping floor key validation ────────────────────────────────────

section('8. Team mapping floor key validation');

// New shape: {"file.json": ["team-slug"]} — validate each referenced settings file.
const NON_OVERRIDABLE_KEYS = new Set([
  'permissions.disableBypassPermissionsMode',
  'sandbox', 'sandbox.enabled', 'sandbox.allowBypass',
  'sandbox.sandboxMcpServers', 'sandbox.sandboxLspServers',
  'sandbox.gitAuth', 'sandbox.ghAuth', 'sandbox.allowDevToolAccess',
  'sandbox.addCurrentWorkingDirectory',
  'sandbox.userPolicy', 'sandbox.userPolicy.filesystem',
  'sandbox.userPolicy.network', 'sandbox.userPolicy.seatbelt',
  'telemetry', 'telemetry.enabled', 'telemetry.endpoint',
  'telemetry.endpointToken', 'telemetry.protocol',
  'telemetry.captureContent', 'telemetry.lockCaptureContent',
  'telemetry.serviceName', 'telemetry.resourceAttributes',
  'telemetry.headers',
  'remoteControl', 'remoteControl.requireSSO',
  'strictKnownMarketplaces',
]);

// FLOOR VALUES — team settings must not set these values on these keys
const FLOOR_KEY_GUARDS = {
  'sandbox.enabled':           false,
  'sandbox.allowBypass':       true,
  'sandbox.sandboxMcpServers': false,
  'sandbox.sandboxLspServers': false,
  'telemetry.lockCaptureContent': false,
  'telemetry.captureContent':     true,
  'strictKnownMarketplaces':      false,
  'permissions.disableBypassPermissionsMode': 'enable',
};

function getNestedValue(obj, keyPath) {
  return keyPath.split('.').reduce((acc, k) => acc?.[k], obj);
}

if (tmGen && typeof tmGen === 'object' && !Array.isArray(tmGen)) {
  let teamFloorOk = true;
  for (const [filePath, teams] of Object.entries(tmGen)) {
    // Validate shape: value must be an array of strings
    if (!Array.isArray(teams) || teams.some(t => typeof t !== 'string' || !t)) {
      fail(`team-mappings.json: "${filePath}" value must be a non-empty array of team slug strings`);
      teamFloorOk = false;
    }
    // Validate referenced file exists
    const teamSettingsPath = path.join(ROOT, filePath);
    if (!existsSync(teamSettingsPath)) {
      fail(`team-mappings.json references missing file: ${filePath}`);
      teamFloorOk = false;
      continue;
    }
    // Parse team settings file and check for non-overridable keys and floor guards
    let teamSettings;
    try {
      teamSettings = parseJsonc(readFileSync(teamSettingsPath, 'utf8'));
    } catch (e) {
      fail(`JSONC parse error in ${filePath}: ${e.message}`);
      teamFloorOk = false;
      continue;
    }
    // Check no non-overridable top-level keys appear
    for (const topKey of Object.keys(teamSettings)) {
      if (NON_OVERRIDABLE_KEYS.has(topKey)) {
        fail(`${filePath}: contains non-overridable key "${topKey}"`);
        teamFloorOk = false;
      }
    }
    // Check floor value guards on nested keys that might appear through permissions
    for (const [keyPath, forbiddenValue] of Object.entries(FLOOR_KEY_GUARDS)) {
      const val = getNestedValue(teamSettings, keyPath);
      if (val !== undefined && val === forbiddenValue) {
        fail(`${filePath}: sets ${keyPath}=${JSON.stringify(val)} — floor value cannot be weakened`);
        teamFloorOk = false;
      }
    }
  }
  if (teamFloorOk) ok('Team mapping floor keys validated');
}

// ─── 9. Link and path existence ───────────────────────────────────────────────

section('9. Path existence');

const REQUIRED_FILES = [
  'README.md', 'AGENTS.md', 'CODEOWNERS', 'package.json',
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

for (const rel of REQUIRED_FILES) {
  const abs = path.join(ROOT, rel);
  if (!existsSync(abs)) {
    fail(`Required file missing: ${rel}`);
  } else {
    ok(`Exists: ${rel}`);
  }
}

// ─── 10. Script existence and executability ───────────────────────────────────

section('10. Scripts');

const REQUIRED_SCRIPTS = [
  'scripts/render-managed-settings.mjs',
  'scripts/validate-governance.mjs',
  'scripts/bootstrap.sh',
];

for (const rel of REQUIRED_SCRIPTS) {
  const abs = path.join(ROOT, rel);
  if (!existsSync(abs)) {
    fail(`Script missing: ${rel}`);
  } else {
    ok(`Script exists: ${rel}`);
  }
}

// ─── 11. No undeclared placeholders in generated JSON ────────────────────────

section('11. Undeclared placeholders');

const { readdirSync: rdSync } = await import('node:fs');
const teamsGenDir = path.join(ROOT, 'copilot', 'teams');
const teamGenFiles = existsSync(teamsGenDir)
  ? rdSync(teamsGenDir).filter(f => f.endsWith('.json') && !f.endsWith('.source.json'))
  : [];

for (const [genPath, label] of [
  [MS_GEN_PATH, 'managed-settings.json'],
  [TM_GEN_PATH, 'team-mappings.json'],
  ...teamGenFiles.map(f => [path.join(teamsGenDir, f), `teams/${f}`]),
]) {
  if (existsSync(genPath)) {
    const content = readFileSync(genPath, 'utf8');
    const found = content.match(/\{\{[A-Z_]+\}\}/g);
    if (found) {
      fail(`${label} contains undeclared placeholders: ${[...new Set(found)].join(', ')}`);
    } else {
      ok(`${label}: no undeclared placeholders`);
    }
  }
}

// ─── Summary ──────────────────────────────────────────────────────────────────

console.log(`\n${'─'.repeat(60)}`);
if (errors === 0 && warnings === 0) {
  console.log('✓ Overlay validation passed with 0 errors, 0 warnings.');
} else if (errors === 0) {
  console.log(`✓ Overlay validation passed with 0 errors, ${warnings} warning(s).`);
} else {
  console.log(`✗ Overlay validation FAILED: ${errors} error(s), ${warnings} warning(s).`);
  process.exit(1);
}
