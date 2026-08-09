import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, extname, join, relative, resolve, sep } from 'node:path';

const AGENT_TOOL_ALIASES = new Set([
  'read',
  'search',
  'edit',
  'execute',
  'agent',
  'web',
  'todo',
]);

const HOOK_EVENTS = new Set([
  'agentStop',
  'errorOccurred',
  'notification',
  'permissionRequest',
  'postToolUse',
  'postToolUseFailure',
  'preCompact',
  'preToolUse',
  'sessionEnd',
  'sessionStart',
  'subagentStart',
  'subagentStop',
  'userPromptSubmitted',
  'userPromptTransformed',
]);

const REQUIRED_AGENT_SECTIONS = [
  '## Purpose',
  '## Non-negotiable invariants',
  '## Route the task to its source',
  '## Repository map',
  '## Validation command routing',
  '## Change and plan expectations',
  '## Security and escalation',
  '## Deeper sources',
];

const LINK_SURFACES = [
  'AGENTS.md',
  '.github/copilot-instructions.md',
  'docs/README.md',
  'docs/agent-support-matrix.md',
];

function walk(root, predicate = () => true) {
  if (!existsSync(root)) return [];
  const files = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    if (['.git', '.terraform', 'node_modules'].includes(entry.name)) continue;
    const path = join(root, entry.name);
    if (entry.isDirectory()) files.push(...walk(path, predicate));
    else if (predicate(path)) files.push(path);
  }
  return files;
}

function text(path) {
  return readFileSync(path, 'utf8');
}

function repoPath(root, path) {
  return relative(root, path).split(sep).join('/');
}

export function parseFrontmatter(source) {
  const start = source.indexOf('---\n');
  if (start === -1 || start > 500) return null;
  const end = source.indexOf('\n---', start + 4);
  if (end === -1) return null;
  const result = {};
  for (const line of source.slice(start + 4, end).split('\n')) {
    const match = line.match(/^([a-zA-Z][\w-]*):\s*(.*)$/);
    if (!match) continue;
    let value = match[2].trim();
    if (/^["'].*["']$/.test(value)) value = value.slice(1, -1);
    else if (value === 'true' || value === 'false') value = value === 'true';
    else if (value.startsWith('[')) {
      try {
        value = JSON.parse(value.replaceAll("'", '"'));
      } catch {
        value = [];
      }
    }
    result[match[1]] = value;
  }
  return result;
}

function slugify(heading) {
  return heading
    .trim()
    .toLowerCase()
    .replace(/[`*_~]/g, '')
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
}

function headingsFor(path) {
  const headings = new Set();
  const counts = new Map();
  for (const line of text(path).split('\n')) {
    const match = line.match(/^#{1,6}\s+(.+?)\s*#*$/);
    if (!match) continue;
    const base = slugify(match[1]);
    const count = counts.get(base) ?? 0;
    headings.add(count === 0 ? base : `${base}-${count}`);
    counts.set(base, count + 1);
  }
  return headings;
}

function markdownLinks(path) {
  const links = [];
  const pattern = /!?\[[^\]]*]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
  for (const match of text(path).matchAll(pattern)) links.push(match[1]);
  return links;
}

function checkLinks(root, errors) {
  const markdown = [
    ...LINK_SURFACES.map((path) => join(root, path)),
    ...walk(join(root, '.github/agents'), (path) => extname(path) === '.md'),
    ...walk(join(root, '.github/prompts'), (path) => extname(path) === '.md'),
    ...walk(join(root, '.github/skills'), (path) => extname(path) === '.md'),
    ...walk(join(root, '.agents/skills'), (path) => extname(path) === '.md'),
    ...walk(join(root, 'docs/standards'), (path) => extname(path) === '.md'),
    ...walk(join(root, 'docs/plans'), (path) => extname(path) === '.md'),
    ...walk(join(root, 'docs/decisions'), (path) => extname(path) === '.md'),
  ].filter(existsSync);

  for (const source of new Set(markdown)) {
    for (const rawLink of markdownLinks(source)) {
      if (/^(https?:|mailto:|tel:)/.test(rawLink)) continue;
      const [rawTarget, anchor] = rawLink.split('#', 2);
      const target = rawTarget
        ? resolve(dirname(source), decodeURIComponent(rawTarget))
        : source;
      if (!existsSync(target)) {
        errors.push(`${repoPath(root, source)}: broken relative link ${rawLink}`);
        continue;
      }
      if (anchor && statSync(target).isFile() && extname(target) === '.md') {
        if (!headingsFor(target).has(decodeURIComponent(anchor).toLowerCase())) {
          errors.push(`${repoPath(root, source)}: missing anchor ${rawLink}`);
        }
      }
    }
  }
}

function checkDocsCatalog(root, errors) {
  const catalogPath = join(root, 'docs/README.md');
  if (!existsSync(catalogPath)) {
    errors.push('docs/README.md: documentation catalog is missing');
    return;
  }
  const catalog = text(catalogPath);
  const docs = walk(join(root, 'docs'), (path) => extname(path) === '.md')
    .map((path) => repoPath(join(root, 'docs'), path))
    .filter((path) => path !== 'README.md');
  for (const doc of docs) {
    if (!catalog.includes(`(${doc})`)) {
      errors.push(`docs/README.md: catalog does not cover ${doc}`);
    }
  }
  for (const line of catalog.split('\n')) {
    if (!line.startsWith('| [`')) continue;
    if (!/\| (Active|Historical|Template) \| \d{4}-\d{2}-\d{2} \|$/.test(line)) {
      errors.push(`docs/README.md: incomplete lifecycle row: ${line}`);
    }
  }
}

function checkAgentMap(root, errors) {
  const path = join(root, 'AGENTS.md');
  const source = text(path);
  const lineCount = source.split('\n').length;
  if (lineCount > 120) errors.push(`AGENTS.md: ${lineCount} lines exceeds 120`);
  for (const section of REQUIRED_AGENT_SECTIONS) {
    if (!source.includes(section)) errors.push(`AGENTS.md: missing ${section}`);
  }

  const bridge = text(join(root, '.github/copilot-instructions.md'));
  if (!bridge.includes('../AGENTS.md')) {
    errors.push('.github/copilot-instructions.md: must start from ../AGENTS.md');
  }
  if (bridge.split('\n').length > 60) {
    errors.push('.github/copilot-instructions.md: bridge exceeds 60 lines');
  }
  for (const duplicate of ['## Project overview', '## Tech stack', '## Build, test']) {
    if (bridge.includes(duplicate)) {
      errors.push(`.github/copilot-instructions.md: duplicates ${duplicate}`);
    }
  }
}

function checkInstructions(root, errors) {
  for (const path of walk(
    join(root, '.github/instructions'),
    (candidate) => candidate.endsWith('.instructions.md'),
  )) {
    const frontmatter = parseFrontmatter(text(path));
    const shown = repoPath(root, path);
    if (!frontmatter) {
      errors.push(`${shown}: missing YAML frontmatter`);
      continue;
    }
    if (!frontmatter.description) errors.push(`${shown}: missing description`);
    if (!frontmatter.applyTo) errors.push(`${shown}: missing applyTo`);
    if (
      ['security.instructions.md', 'review.instructions.md'].includes(
        shown.split('/').at(-1),
      ) &&
      frontmatter.applyTo === '**'
    ) {
      errors.push(`${shown}: concise hand-authored guidance must be path scoped`);
    }
  }
}

function toolsFrom(frontmatter) {
  return Array.isArray(frontmatter?.tools) ? frontmatter.tools : [];
}

function checkAgents(root, errors) {
  const chatmodes = walk(
    join(root, '.github/chatmodes'),
    (path) => path.endsWith('.chatmode.md'),
  );
  if (chatmodes.length > 0) errors.push('obsolete .chatmode.md files remain');

  for (const path of walk(
    join(root, '.github/agents'),
    (candidate) => candidate.endsWith('.agent.md'),
  )) {
    const frontmatter = parseFrontmatter(text(path));
    const shown = repoPath(root, path);
    if (!frontmatter?.description) errors.push(`${shown}: missing description`);
    if ('infer' in (frontmatter ?? {})) errors.push(`${shown}: infer is retired`);
    for (const tool of toolsFrom(frontmatter)) {
      if (!AGENT_TOOL_ALIASES.has(tool) && !tool.includes('/')) {
        errors.push(`${shown}: unsupported tool alias ${tool}`);
      }
    }
  }
}

function checkPrompts(root, errors) {
  for (const path of walk(
    join(root, '.github/prompts'),
    (candidate) => candidate.endsWith('.prompt.md'),
  )) {
    const frontmatter = parseFrontmatter(text(path));
    const shown = repoPath(root, path);
    if (!frontmatter?.agent) errors.push(`${shown}: missing agent metadata`);
    if ('mode' in (frontmatter ?? {})) errors.push(`${shown}: mode is obsolete`);
  }
}

function checkHooks(root, errors) {
  for (const path of walk(
    join(root, '.github/hooks'),
    (candidate) => extname(candidate) === '.json',
  )) {
    const shown = repoPath(root, path);
    let config;
    try {
      config = JSON.parse(text(path));
    } catch (error) {
      errors.push(`${shown}: invalid JSON (${error.message})`);
      continue;
    }
    if (config.version !== 1 || typeof config.hooks !== 'object') {
      errors.push(`${shown}: expected version 1 hooks schema`);
      continue;
    }
    for (const [event, entries] of Object.entries(config.hooks)) {
      if (!HOOK_EVENTS.has(event)) errors.push(`${shown}: invalid event ${event}`);
      if (!Array.isArray(entries)) {
        errors.push(`${shown}: ${event} must be an array`);
        continue;
      }
      for (const entry of entries) {
        if (entry.type !== 'command') {
          errors.push(`${shown}: only deterministic command hooks are allowed`);
        }
        if (!entry.bash || !entry.powershell) {
          errors.push(`${shown}: command hook needs Bash and PowerShell entries`);
        }
        const serialized = JSON.stringify(entry);
        if (serialized.includes('npx')) errors.push(`${shown}: hooks cannot run npx`);
        for (const command of [entry.bash, entry.powershell].filter(Boolean)) {
          const script = command.match(/(?:^|\s)(\.\/\.github\/hooks\/scripts\/[^\s"]+)/)?.[1];
          if (script && !existsSync(resolve(root, script))) {
            errors.push(`${shown}: missing hook script ${script}`);
          }
        }
      }
    }
  }
}

export function checkMcp(root, errors) {
  const cloudPath = join(root, '.github/mcp/mcp.json');
  const editorPath = join(root, '.vscode/mcp.json');
  const parsed = new Map();
  const sources = new Map();
  for (const path of [cloudPath, editorPath]) {
    if (!existsSync(path)) {
      errors.push(`${repoPath(root, path)}: MCP configuration is missing`);
      continue;
    }
    const source = text(path);
    sources.set(path, source);
    try {
      parsed.set(path, JSON.parse(source));
    } catch (error) {
      errors.push(`${repoPath(root, path)}: invalid strict JSON (${error.message})`);
    }
    if (/@latest\b/.test(source)) errors.push(`${repoPath(root, path)}: latest is forbidden`);
    if (/Authorization|Bearer\s|api[_-]?key|"\*"/i.test(source)) {
      errors.push(`${repoPath(root, path)}: secret/wildcard pattern is forbidden`);
    }
  }

  const cloud = parsed.get(cloudPath);
  if (cloud) {
    for (const [name, server] of Object.entries(cloud.mcpServers ?? {})) {
      if (['github', 'playwright', 'azure'].includes(name.toLowerCase())) {
        errors.push(`.github/mcp/mcp.json: do not duplicate built-in or authenticated ${name}`);
      }
      if (!Array.isArray(server.tools) || server.tools.length === 0) {
        errors.push(`.github/mcp/mcp.json: ${name} needs a tool allowlist`);
      }
    }
  }

  const editor = sources.get(editorPath) ?? '';
  if (editor.includes('@azure/mcp"') || editor.includes('@azure/mcp",')) {
    errors.push('.vscode/mcp.json: Azure MCP must use an exact version');
  }
}

function checkActions(root, errors) {
  for (const path of walk(
    join(root, '.github/workflows'),
    (candidate) => /\.ya?ml$/.test(candidate),
  )) {
    for (const [index, line] of text(path).split('\n').entries()) {
      const match = line.match(/^\s*(?:-\s*)?uses:\s*([^#\s]+)/);
      if (!match || match[1].startsWith('./')) continue;
      if (!/@[0-9a-fA-F]{40}$/.test(match[1])) {
        errors.push(`${repoPath(root, path)}:${index + 1}: action is not SHA pinned`);
      }
    }
  }
}

function checkApm(root, errors) {
  const lock = text(join(root, 'apm.lock.yaml'));
  for (const removed of [
    'code-review-generic.instructions.md',
    'security-and-owasp.instructions.md',
  ]) {
    if (lock.includes(removed)) errors.push(`apm.lock.yaml: oversized ${removed} remains`);
  }
  for (const match of lock.matchAll(/^\s*-\s+(\.(?:github|agents)\/[^\s]+)$/gm)) {
    if (!existsSync(join(root, match[1]))) {
      errors.push(`apm.lock.yaml: deployed file is missing: ${match[1]}`);
    }
  }
}

function checkStructures(root, errors) {
  for (const required of [
    'docs/plans/README.md',
    'docs/plans/template.md',
    'docs/plans/active/README.md',
    'docs/plans/completed/README.md',
    'docs/decisions/README.md',
    'docs/decisions/template.md',
    'docs/decisions/0001-canonical-agent-context.md',
  ]) {
    if (!existsSync(join(root, required))) errors.push(`${required}: required structure missing`);
  }
  const planTemplate = text(join(root, 'docs/plans/template.md'));
  for (const heading of ['## Scope', '## Progress', '## Decision log', '## Verification']) {
    if (!planTemplate.includes(heading)) errors.push(`docs/plans/template.md: missing ${heading}`);
  }
}

export function validateRepository(root) {
  const errors = [];
  checkAgentMap(root, errors);
  checkLinks(root, errors);
  checkDocsCatalog(root, errors);
  checkInstructions(root, errors);
  checkAgents(root, errors);
  checkPrompts(root, errors);
  checkHooks(root, errors);
  checkMcp(root, errors);
  checkActions(root, errors);
  checkApm(root, errors);
  checkStructures(root, errors);
  return errors;
}
