import assert from 'node:assert/strict';
import { test } from 'node:test';

import pino from 'pino';
import request from 'supertest';

import { createApp } from './app.js';

const testLogger = pino({ level: 'silent' });
const app = createApp({ logger: testLogger });

test('GET / serves the semantic showcase HTML', async () => {
  const response = await request(app).get('/');

  assert.equal(response.status, 200);
  assert.match(response.headers['content-type'], /^text\/html/);
  assert.match(response.text, /<header\b/);
  assert.match(response.text, /<nav\b[^>]*aria-label=/);
  assert.match(response.text, /<main\b/);
  assert.match(response.text, /<footer\b/);
  assert.match(response.text, /aria-live="polite"/);
  assert.match(response.text, /<script type="module" src="\/app\.js"><\/script>/);
  assert.doesNotMatch(response.text, /<style\b|<script(?! type="module")/);
});

test('GET /api/info returns versioned safe build and runtime metadata', async () => {
  const response = await request(app).get('/api/info');

  assert.equal(response.status, 200);
  assert.equal(response.body.name, 'agentic-sdlc-sample-app');
  assert.equal(response.body.version, '0.1.0');
  assert.equal(typeof response.body.runtime.node, 'string');
  assert.equal(response.body.runtime.environment, 'development');
  assert.deepEqual(Object.keys(response.body.build).sort(), [
    'builtAt',
    'repository',
    'sha',
  ]);
});

test('GET /health preserves compatibility and disables caching', async () => {
  const response = await request(app).get('/health');

  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'ok');
  assert.equal(typeof response.body.uptime, 'number');
  assert.ok(response.body.uptime >= 0);
  assert.equal(response.headers['cache-control'], 'no-store');
});

test('security headers enforce a same-origin CSP without unsafe directives', async () => {
  const response = await request(app).get('/');
  const csp = response.headers['content-security-policy'];

  assert.match(csp, /default-src 'self'/);
  assert.match(csp, /script-src 'self'/);
  assert.match(csp, /style-src 'self'/);
  assert.match(csp, /frame-ancestors 'none'/);
  assert.doesNotMatch(csp, /unsafe-inline|unsafe-eval/);
  assert.equal(response.headers['x-content-type-options'], 'nosniff');
  assert.equal(response.headers['x-frame-options'], 'SAMEORIGIN');
  assert.equal(
    response.headers['referrer-policy'],
    'strict-origin-when-cross-origin',
  );
  assert.equal(
    response.headers['permissions-policy'],
    'camera=(), microphone=(), geolocation=(), payment=()',
  );
});

test('unknown routes return an explicit cache-safe 404', async () => {
  const response = await request(app).get('/missing');

  assert.equal(response.status, 404);
  assert.equal(response.body.error.code, 'not_found');
  assert.equal(response.headers['cache-control'], 'no-store');
  assert.equal(typeof response.body.error.requestId, 'string');
});

test('request bodies larger than 100kb are rejected centrally', async () => {
  const response = await request(app)
    .post('/api/info')
    .send({ data: 'x'.repeat(102_400) });

  assert.equal(response.status, 413);
  assert.equal(response.body.error.code, 'payload_too_large');
});

test('malformed JSON receives a structured 400 response', async () => {
  const response = await request(app)
    .post('/api/info')
    .set('Content-Type', 'application/json')
    .send('{"broken"');

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, 'invalid_json');
});

test('central error responses never leak internal messages or stacks', async () => {
  const errorApp = createApp({
    logger: testLogger,
    registerRoutes(expressApp) {
      expressApp.get('/test-error', () => {
        throw new Error('TEST_DATABASE_PASSWORD must remain private');
      });
    },
  });
  const response = await request(errorApp).get('/test-error');
  const serialized = JSON.stringify(response.body);

  assert.equal(response.status, 500);
  assert.equal(response.body.error.code, 'internal_error');
  assert.equal(response.body.error.message, 'Internal Server Error');
  assert.doesNotMatch(serialized, /TEST_DATABASE_PASSWORD|stack/i);
});

test('HTML and APIs are no-store while versionable assets are cacheable', async () => {
  const [root, info, asset] = await Promise.all([
    request(app).get('/'),
    request(app).get('/api/info'),
    request(app).get('/styles.css'),
  ]);

  assert.equal(root.headers['cache-control'], 'no-store');
  assert.equal(info.headers['cache-control'], 'no-store');
  assert.match(asset.headers['cache-control'], /public, max-age=3600/);
});

test('request IDs preserve safe caller IDs and replace invalid input', async () => {
  const safe = await request(app)
    .get('/health')
    .set('X-Request-Id', 'trace:test-123');
  const unsafe = await request(app)
    .get('/health')
    .set('X-Request-Id', 'line-break value');

  assert.equal(safe.headers['x-request-id'], 'trace:test-123');
  assert.notEqual(unsafe.headers['x-request-id'], 'line-break value');
  assert.match(unsafe.headers['x-request-id'], /^[0-9a-f-]{36}$/);
});
