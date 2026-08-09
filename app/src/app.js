import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import express from 'express';
import helmet from 'helmet';

import { logger as defaultLogger } from './lib/logger.js';
import { errorHandler } from './middleware/errors.js';
import { notFoundHandler } from './middleware/not-found.js';
import { createRequestLogger } from './middleware/request-logging.js';
import { healthRouter } from './routes/health.js';
import { infoRouter } from './routes/info.js';

const publicDirectory = fileURLToPath(new URL('../public', import.meta.url));
const indexHtml = readFileSync(
  new URL('../public/index.html', import.meta.url),
  'utf8',
);

const contentSecurityPolicy = {
  useDefaults: false,
  directives: {
    defaultSrc: ["'self'"],
    baseUri: ["'self'"],
    connectSrc: ["'self'"],
    fontSrc: ["'self'"],
    formAction: ["'self'"],
    frameAncestors: ["'none'"],
    imgSrc: ["'self'"],
    objectSrc: ["'none'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'"],
  },
};

export function createApp({
  logger = defaultLogger,
  registerRoutes,
} = {}) {
  const app = express();

  app.disable('x-powered-by');
  app.use(createRequestLogger(logger));
  app.use(
    helmet({
      contentSecurityPolicy,
      crossOriginOpenerPolicy: { policy: 'same-origin' },
      crossOriginResourcePolicy: { policy: 'same-origin' },
      referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
    }),
  );
  app.use((_req, res, next) => {
    res.set(
      'Permissions-Policy',
      'camera=(), microphone=(), geolocation=(), payment=()',
    );
    next();
  });
  app.use(express.json({ limit: '100kb' }));

  app.get('/', (_req, res) => {
    res
      .set('Cache-Control', 'no-store')
      .type('html')
      .status(200)
      .send(indexHtml);
  });
  app.use(
    express.static(publicDirectory, {
      index: false,
      maxAge: '1h',
    }),
  );
  app.use(healthRouter);
  app.use(infoRouter);

  if (registerRoutes) {
    registerRoutes(app);
  }

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
