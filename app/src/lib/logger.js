import pino from 'pino';

import { env } from './env.js';

export function createLogger(environment = env) {
  return pino({
    name: 'agentic-sdlc-sample-app',
    level: environment.LOG_LEVEL,
    base: {
      service: 'agentic-sdlc-sample-app',
      environment: environment.NODE_ENV,
    },
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.headers["x-api-key"]',
        'req.body.password',
        'req.body.secret',
        'req.body.token',
        'res.headers["set-cookie"]',
      ],
      censor: '[Redacted]',
    },
  });
}

export const logger = createLogger();
