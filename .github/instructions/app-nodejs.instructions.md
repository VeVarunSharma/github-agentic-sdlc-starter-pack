<!-- HAND-AUTHORED — path-scoped instructions for the Node.js sample app. -->
---
description: "Node.js 22 + Express conventions for the sample app"
applyTo: "app/**/*.{js,mjs}"
---

# Node.js + Express conventions (`app/**`)

These rules apply to every `.js` / `.mjs` file under `app/`. They are loaded
automatically by GitHub Copilot whenever a file matching `applyTo` is in
context. Keep them concrete and prescriptive — Copilot follows imperative
guidance better than abstract principles.

## Runtime and module system

- **Node.js 22** is the only supported runtime. Use features available in
  Node 22 freely (top-level `await`, native `fetch`, `node:test`,
  `node:assert`, structured clone). Do not add transpilation.
- **ES modules only** (`"type": "module"` in `app/package.json`). Use
  `import`/`export`, never `require`/`module.exports`.
- Use the `node:` prefix for Node built-ins: `import { test } from
  'node:test'`, `import assert from 'node:assert/strict'`,
  `import { readFile } from 'node:fs/promises'`.

## File layout

- Route handlers live in `app/src/routes/<name>.js`.
- Business logic lives in `app/src/services/<name>.js`.
- Cross-cutting helpers live in `app/src/lib/<name>.js`.
- The Express app factory lives in `app/src/app.js`; the process entry
  point lives in `app/src/server.js` and only handles `listen()` /
  signal handling.

## Route handler shape

Keep handlers thin: validate input, call a service, shape the response.

```js
import { Router } from 'express';
import { getHealth } from '../services/health.js';

export const healthRouter = Router();

healthRouter.get('/health', async (req, res, next) => {
  try {
    const status = await getHealth();
    res.json(status);
  } catch (err) {
    next(err);
  }
});
```

- Use `async`/`await`. Never use `.then()`/`.catch()` chains.
- Always pass errors to `next(err)`; let the central error middleware
  format the response. Never call `res.status(500).send(...)` from a
  handler directly.
- Return JSON via `res.json(obj)`. Do not hand-build `Content-Type`
  headers for JSON responses.

## Error handling

- Throw `Error` subclasses with named types when the caller needs to
  distinguish (e.g. `class NotFoundError extends Error {}` in
  `app/src/lib/errors.js`).
- The central error middleware lives in `app/src/middleware/errors.js`
  and maps known error classes to HTTP status codes; everything else
  becomes a `500`.
- Never swallow errors silently. If a `catch` block has no `throw` /
  `next(err)` / log call, that is a bug.

## Input validation

- Validate request bodies and query params at the route boundary using
  Zod. Reject early with `400` and a structured error body.
- Treat all `req.body`, `req.query`, `req.params`, and `req.headers`
  values as untrusted — never interpolate them into shell commands,
  SQL, file paths, or `eval`-equivalent constructs.

## Testing

- Use Node's built-in `node:test` runner — no extra test framework.
  Run via `npm test` (which runs `node --test`).
- Co-locate tests next to source: `app/src/routes/health.js` ↔
  `app/src/routes/health.test.js`.
- Use `node:assert/strict` for assertions.
- Test the Express app via `supertest` against the app factory, not
  against a live server:

  ```js
  import { test } from 'node:test';
  import assert from 'node:assert/strict';
  import request from 'supertest';
  import { createApp } from '../app.js';

  test('GET /health returns ok', async () => {
    const res = await request(createApp()).get('/health');
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { status: 'ok' });
  });
  ```

- New features ship with at least one happy-path test. PRs without
  tests for new code paths will be rejected by the reviewer (human or
  agent).

## Logging

- Use `pino` with JSON output. The logger is created in
  `app/src/lib/logger.js`; import it where needed.
- Never `console.log` in production code paths. `console.*` is allowed
  only in scripts under `app/scripts/` and in tests.

## Security

- No `eval`, `new Function(...)`, or dynamic `require`/`import`
  with user input.
- Set `helmet()` middleware on the app. Set `express.json({ limit:
  '100kb' })` to cap request body size.
- Read secrets from environment variables only. Never hard-code
  secrets, even in tests — use the `TEST_*` prefix for fixture
  values.
