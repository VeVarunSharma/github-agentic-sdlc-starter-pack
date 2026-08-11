#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, isAbsolute, relative, resolve, sep } from 'node:path';

const RELEVANT_PATH = /^(AGENTS\.md|docs\/|\.github\/(agents|hooks|instructions|mcp|prompts|skills|workflows)\/|\.vscode\/|tools\/harness\/|scripts\/)/;
const EDIT_TOOL = /(edit|write|create|apply[_-]?patch|multiEdit)/i;

function collectStrings(value, result = []) {
  if (typeof value === 'string') result.push(value);
  else if (Array.isArray(value)) value.forEach((item) => collectStrings(item, result));
  else if (value && typeof value === 'object') {
    Object.values(value).forEach((item) => collectStrings(item, result));
  }
  return result;
}

export function parseHookPayload(source) {
  const payload = JSON.parse(source);
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new TypeError('hook payload must be a JSON object');
  }
  return payload;
}

export function shouldValidate(payload) {
  if (!('toolName' in payload)) return true;
  if (!EDIT_TOOL.test(String(payload.toolName))) return false;
  const values = collectStrings(payload.toolArgs);
  const cwd = resolve(String(payload.cwd ?? process.cwd()));
  return values.length === 0 || values.some((value) => {
    const candidate = String(value).trim();
    if (candidate === '') return false;
    const normalized = (
      isAbsolute(candidate) ? relative(cwd, resolve(candidate)) : candidate
    )
      .split(sep)
      .join('/')
      .replace(/^\.\//, '');
    return !normalized.startsWith('../') && RELEVANT_PATH.test(normalized);
  });
}

export function validationResult(payload, run = runHarness) {
  if (!shouldValidate(payload)) return { output: {}, exitCode: 0 };
  const result = run();
  if (result.status === 0) return { output: {}, exitCode: 0 };
  const detail = `${result.error?.message ?? ''}\n${result.stdout ?? ''}\n${result.stderr ?? ''}`
    .trim()
    .slice(-4000);
  const message = `Deterministic agent harness validation failed. Fix these errors before stopping:\n${detail}`;
  if (!('toolName' in payload)) {
    return {
      output: {
        decision: 'block',
        reason: message,
      },
      exitCode: 0,
    };
  }
  return {
    output: {
      additionalContext: message,
    },
    exitCode: 0,
  };
}

function runHarness() {
  return spawnSync(
    process.execPath,
    [resolve(dirname(fileURLToPath(import.meta.url)), 'cli.mjs')],
    { encoding: 'utf8' },
  );
}

if (fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  let source = '';
  process.stdin.setEncoding('utf8');
  for await (const chunk of process.stdin) source += chunk;
  try {
    const result = validationResult(parseHookPayload(source));
    process.stdout.write(`${JSON.stringify(result.output)}\n`);
    process.exitCode = result.exitCode;
  } catch (error) {
    process.stdout.write(
      `${JSON.stringify({ additionalContext: `Invalid lifecycle hook input: ${error.message}` })}\n`,
    );
    process.exitCode = 1;
  }
}
