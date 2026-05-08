const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../index.js');

let server;
let baseUrl;

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, () => {
      const { port } = server.address();
      baseUrl = `http://127.0.0.1:${port}`;
      resolve();
    });
  });
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

test('GET / returns name and version', async () => {
  const res = await fetch(`${baseUrl}/`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.name, 'agentic-sdlc-sample-app');
  assert.equal(typeof body.version, 'string');
  assert.ok(body.version.length > 0);
});

test('GET /health returns ok and numeric uptime', async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, 'ok');
  assert.equal(typeof body.uptime, 'number');
  assert.ok(body.uptime >= 0);
});
