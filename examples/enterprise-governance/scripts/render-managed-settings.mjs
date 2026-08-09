#!/usr/bin/env node
// scripts/render-managed-settings.mjs
//
// Deterministic renderer for copilot/managed-settings.source.jsonc →
// copilot/managed-settings.json and copilot/team-mappings.source.jsonc →
// copilot/team-mappings.json.
//
// USAGE
//   node scripts/render-managed-settings.mjs \
//     --enterprise ENTERPRISE_SLUG \
//     --organization ORG_SLUG \
//     --governance-repo REPO_NAME \
//     --otlp-endpoint https://otel.example.internal \
//     [--check]            # verify generated files match without writing
//     [--deploy-env ENV]   # environment label (default: production)
//     [--internal-mcp-url URL]  # internal MCP server URL
//
// SECURITY
//   • Never pass secrets (tokens, passwords) as command-line arguments.
//     Use environment variables OTLP_ENDPOINT_TOKEN for bearer tokens.
//   • The renderer validates that no {{PLACEHOLDER}} tokens remain in
//     generated output (--check mode or deploy mode both enforce this).
//   • Secrets must NOT appear in source files — only in environment vars.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

// ─── Argument parsing ────────────────────────────────────────────────────────

const args = process.argv.slice(2);

function flag(name) {
  return args.includes(`--${name}`);
}

function opt(name, required = false) {
  const idx = args.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= args.length) {
    if (required) {
      console.error(`ERROR: --${name} is required`);
      process.exit(1);
    }
    return null;
  }
  return args[idx + 1];
}

function showHelp() {
  console.log(`
render-managed-settings.mjs — Render JSONC governance sources to strict JSON

USAGE
  node scripts/render-managed-settings.mjs \\
    --enterprise SLUG        GitHub Enterprise slug (required)
    --organization SLUG      GitHub organization slug (required)
    --governance-repo NAME   .github-private repository name (required)
    --otlp-endpoint URL      OTLP receiver base URL (required)
    [--deploy-env ENV]       Deployment environment label (default: production)
    [--internal-mcp-url URL] Internal MCP server URL (default: placeholder)
    [--check]                Verify generated files match without writing
    [--help]                 Show this help

ENVIRONMENT VARIABLES
  OTLP_ENDPOINT_TOKEN       Bearer token for the OTLP endpoint
                            (required when rendering for deployment;
                             may be a safe demo value in check mode)

EXAMPLES
  # Render with your values:
  node scripts/render-managed-settings.mjs \\
    --enterprise acme-corp \\
    --organization acme-engineering \\
    --governance-repo .github-private \\
    --otlp-endpoint https://otel.acme.internal

  # Check that committed generated files are up to date (CI):
  node scripts/render-managed-settings.mjs \\
    --enterprise example-org \\
    --organization example-org \\
    --governance-repo .github-private \\
    --otlp-endpoint https://otel.example.internal \\
    --check
`);
}

if (flag('help')) {
  showHelp();
  process.exit(0);
}

const CHECK_MODE = flag('check');
const ENTERPRISE  = opt('enterprise',       !CHECK_MODE);
const ORG         = opt('organization',     !CHECK_MODE);
const GOV_REPO    = opt('governance-repo',  !CHECK_MODE);
const OTLP_EP     = opt('otlp-endpoint',   !CHECK_MODE);
const DEPLOY_ENV  = opt('deploy-env') ?? 'production';
const INT_MCP_URL = opt('internal-mcp-url') ?? 'https://mcp.example.internal/standards';

// In check mode without explicit args, use safe demo values for comparison
const enterprise  = ENTERPRISE  ?? 'example-org';
const org         = ORG         ?? 'example-org';
const govRepo     = GOV_REPO    ?? '.github-private';
const otlpEp      = OTLP_EP     ?? 'https://otel.example.internal/v1/traces';

// ─── JSONC parser (comments + trailing commas) ───────────────────────────────

/**
 * Minimal JSONC parser: strips // and block comments, trailing commas, then
 * parses with JSON.parse. Not a full JSONC spec implementation but sufficient
 * for well-formed governance source files.
 * @param {string} src
 * @returns {unknown}
 */
function parseJsonc(src) {
  // String-aware JSONC parser — correctly skips comments inside string values.
  // A naive regex approach breaks on https:// in URL string values.
  let result = '';
  let i = 0;
  while (i < src.length) {
    if (src[i] === '"') {
      // Copy JSON string verbatim, respecting escape sequences.
      result += src[i++];
      while (i < src.length) {
        if (src[i] === '\\') { result += src[i] + src[i + 1]; i += 2; continue; }
        if (src[i] === '"') { result += src[i++]; break; }
        result += src[i++];
      }
    } else if (src[i] === '/' && src[i + 1] === '/') {
      // Line comment — skip to end of line, preserving the newline.
      while (i < src.length && src[i] !== '\n') i++;
    } else if (src[i] === '/' && src[i + 1] === '*') {
      // Block comment — skip until closing */.
      i += 2;
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i++;
      i += 2;
    } else {
      result += src[i++];
    }
  }
  // Remove trailing commas before } or ]
  result = result.replace(/,(\s*[}\]])/g, '$1');
  try {
    return JSON.parse(result);
  } catch (err) {
    throw new Error(`JSONC parse error: ${err.message}`);
  }
}

// ─── Token substitution ──────────────────────────────────────────────────────

const OTLP_TOKEN = process.env.OTLP_ENDPOINT_TOKEN ?? 'DEMO_TOKEN_NOT_FOR_PRODUCTION';

// Token map — all {{PLACEHOLDER}} tokens that appear in source files.
// To add a new token, add it here and document it in managed-settings.source.jsonc.
const TOKEN_MAP = {
  '{{ENTERPRISE_SLUG}}':         enterprise,
  '{{ORG_SLUG}}':                org,
  '{{GOVERNANCE_REPO}}':         govRepo,
  '{{OTLP_ENDPOINT}}':           otlpEp.endsWith('/v1/traces') ? otlpEp : `${otlpEp}/v1/traces`,
  '{{OTLP_ENDPOINT_TOKEN}}':     OTLP_TOKEN,
  '{{DEPLOY_ENV}}':              DEPLOY_ENV,
  '{{INTERNAL_MCP_URL}}':        INT_MCP_URL,
  '{{GOVERNANCE_MARKETPLACE_URL}}': `https://raw.githubusercontent.com/${org}/${govRepo}/main/.github/plugin/marketplace.json`,
  // Team tokens — demo values; replace in bootstrap setup
  '{{STANDARD_DEVELOPERS_TEAM}}': 'developers',
  '{{AI_PIONEERS_TEAM}}':         'ai-platform-pioneers',
};

/**
 * Validate token values — reject secrets in source files and
 * reject unresolved tokens in rendered output.
 */
function validateTokens(tokenMap) {
  for (const [token, value] of Object.entries(tokenMap)) {
    if (!value || value.trim() === '') {
      throw new Error(`Token ${token} resolved to empty string`);
    }
    // Reject obvious secret patterns in rendered values
    if (token !== '{{OTLP_ENDPOINT_TOKEN}}') {
      if (/^(sk-|ghp_|github_pat_|Bearer |Token )/i.test(value)) {
        throw new Error(`Token ${token} value looks like a secret — use environment variables`);
      }
    }
  }
}

/**
 * Substitute all {{PLACEHOLDER}} tokens in a string.
 */
function substitute(text, tokenMap) {
  let result = text;
  for (const [token, value] of Object.entries(tokenMap)) {
    result = result.split(token).join(value);
  }
  return result;
}

/**
 * Check for unresolved placeholder tokens in rendered text.
 */
function checkUnresolved(text, label) {
  const unresolved = text.match(/\{\{[A-Z_]+\}\}/g);
  if (unresolved) {
    throw new Error(
      `Unresolved placeholder tokens in ${label}: ${[...new Set(unresolved)].join(', ')}\n` +
      'Add them to TOKEN_MAP in render-managed-settings.mjs or pass via --flag.'
    );
  }
}

// ─── Render a JSONC source file to strict JSON ───────────────────────────────

/**
 * Render a JSONC source file to a strict JSON string with stable formatting.
 * @param {string} sourcePath
 * @param {Record<string, string>} tokenMap
 * @returns {string} - formatted JSON string with trailing newline
 */
function renderSource(sourcePath, tokenMap) {
  if (!existsSync(sourcePath)) {
    throw new Error(`Source file not found: ${sourcePath}`);
  }
  const raw = readFileSync(sourcePath, 'utf8');
  const substituted = substitute(raw, tokenMap);
  const parsed = parseJsonc(substituted);

  // Strip _comment keys from rendered output
  const stripped = deepStripCommentKeys(parsed);

  // Stable, deterministic JSON output (2-space indent, sorted top-level keys)
  return JSON.stringify(stripped, stableReplacer, 2) + '\n';
}

/**
 * Recursively remove keys starting with "_comment" from an object.
 */
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

/**
 * Stable JSON replacer: sorts object keys alphabetically for deterministic output.
 */
function stableReplacer(key, value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return Object.fromEntries(
      Object.entries(value).sort(([a], [b]) => a.localeCompare(b))
    );
  }
  return value;
}

// ─── Validate owner/org/repo/URL tokens ─────────────────────────────────────

/**
 * Validate that identifiers conform to GitHub slug rules.
 */
function validateSlug(value, label) {
  if (!/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/.test(value)) {
    throw new Error(`${label} "${value}" is not a valid GitHub slug (alphanumeric + hyphens)`);
  }
}

/**
 * Validate that a URL is HTTPS and has a recognizable hostname.
 */
function validateHttpsUrl(value, label) {
  try {
    const u = new URL(value);
    if (u.protocol !== 'https:') {
      throw new Error(`${label} must use HTTPS (got "${u.protocol}")`);
    }
  } catch (err) {
    if (err.message.includes('HTTPS')) throw err;
    throw new Error(`${label} "${value}" is not a valid URL`);
  }
}

// ─── Main ────────────────────────────────────────────────────────────────────

try {
  validateTokens(TOKEN_MAP);

  if (!CHECK_MODE) {
    // Validate slug formats for deploy values
    validateSlug(enterprise, 'enterprise');
    validateSlug(org, 'organization');
    validateSlug(govRepo.replace(/^\./, ''), 'governance-repo');
    validateHttpsUrl(otlpEp, 'otlp-endpoint');
    validateHttpsUrl(INT_MCP_URL, 'internal-mcp-url');
  }

  // Render managed settings
  const msSource = path.join(ROOT, 'copilot', 'managed-settings.source.jsonc');
  const msTarget = path.join(ROOT, 'copilot', 'managed-settings.json');
  const msRendered = renderSource(msSource, TOKEN_MAP);
  checkUnresolved(msRendered, 'managed-settings.json');

  // Render team mappings
  const tmSource = path.join(ROOT, 'copilot', 'team-mappings.source.jsonc');
  const tmTarget = path.join(ROOT, 'copilot', 'team-mappings.json');
  const tmRendered = renderSource(tmSource, TOKEN_MAP);
  checkUnresolved(tmRendered, 'team-mappings.json');

  // Render individual team settings files (copilot/teams/*.source.jsonc)
  const { readdirSync } = await import('node:fs');
  const teamsDir = path.join(ROOT, 'copilot', 'teams');
  const teamFiles = existsSync(teamsDir)
    ? readdirSync(teamsDir).filter(f => f.endsWith('.source.jsonc'))
    : [];
  const teamPairs = teamFiles.map(f => {
    const src = path.join(teamsDir, f);
    const target = path.join(teamsDir, f.replace('.source.jsonc', '.json'));
    const label = `teams/${f.replace('.source.jsonc', '.json')}`;
    const rendered = renderSource(src, TOKEN_MAP);
    checkUnresolved(rendered, label);
    return [target, rendered, label];
  });

  if (CHECK_MODE) {
    // Verify byte-exact match with committed generated files
    let failures = 0;
    for (const [target, rendered, label] of [
      [msTarget, msRendered, 'managed-settings.json'],
      [tmTarget, tmRendered, 'team-mappings.json'],
      ...teamPairs,
    ]) {
      if (!existsSync(target)) {
        console.error(`FAIL: ${label} — generated file does not exist (run without --check to generate)`);
        failures++;
        continue;
      }
      const committed = readFileSync(target, 'utf8');
      if (committed !== rendered) {
        console.error(`FAIL: ${label} — committed file does not match rendered output.`);
        console.error('Run without --check to regenerate, then commit the result.');
        failures++;
      } else {
        console.log(`OK: ${label} is up to date`);
      }
    }
    if (failures > 0) process.exit(1);
  } else {
    // Write generated files
    writeFileSync(msTarget, msRendered, 'utf8');
    console.log(`Wrote: copilot/managed-settings.json`);
    writeFileSync(tmTarget, tmRendered, 'utf8');
    console.log(`Wrote: copilot/team-mappings.json`);
    for (const [target, rendered, label] of teamPairs) {
      writeFileSync(target, rendered, 'utf8');
      console.log(`Wrote: copilot/${label}`);
    }
    console.log('Render complete. Validate with: node scripts/validate-governance.mjs');
  }
} catch (err) {
  console.error(`ERROR: ${err.message}`);
  process.exit(1);
}
