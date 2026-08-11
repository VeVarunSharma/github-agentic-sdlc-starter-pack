import assert from 'node:assert/strict';
import { test } from 'node:test';

import { parseEnvironment } from './env.js';

test('parseEnvironment applies safe local defaults', () => {
  const parsed = parseEnvironment({});

  assert.equal(parsed.NODE_ENV, 'development');
  assert.equal(parsed.PORT, 3000);
  assert.equal(parsed.APPLICATIONINSIGHTS_CONNECTION_STRING, undefined);
});

test('parseEnvironment rejects invalid ports without exposing source values', () => {
  assert.throws(
    () => parseEnvironment({ PORT: '70000' }),
    /Invalid environment configuration: PORT:/,
  );
});

test('parseEnvironment treats a blank telemetry connection string as absent', () => {
  const parsed = parseEnvironment({
    APPLICATIONINSIGHTS_CONNECTION_STRING: '   ',
  });

  assert.equal(parsed.APPLICATIONINSIGHTS_CONNECTION_STRING, undefined);
});
