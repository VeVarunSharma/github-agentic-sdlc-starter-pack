#!/usr/bin/env node
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateRepository } from './validate.mjs';

const packageRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));
const defaultRoot = resolve(packageRoot, '../..');
const root = resolve(process.env.HARNESS_ROOT ?? defaultRoot);
const errors = validateRepository(root);

if (errors.length > 0) {
  for (const error of errors) process.stderr.write(`ERROR: ${error}\n`);
  process.stderr.write(`${errors.length} harness validation failure(s)\n`);
  process.exitCode = 1;
} else {
  process.stdout.write('Agent harness validation passed.\n');
}
