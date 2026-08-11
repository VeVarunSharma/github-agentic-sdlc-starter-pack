import { createApp } from './app.js';
import { env } from './lib/env.js';
import { logger } from './lib/logger.js';

const app = createApp();
const server = app.listen(env.PORT, () => {
  logger.info({ port: env.PORT }, 'HTTP server listening');
});

let shuttingDown = false;

function shutdown(signal, exitCode = 0) {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;

  logger.info({ signal }, 'Graceful shutdown started');
  const timeout = setTimeout(() => {
    logger.error('Graceful shutdown timed out');
    server.closeAllConnections();
    process.exit(1);
  }, 10_000);
  timeout.unref();

  server.close((error) => {
    clearTimeout(timeout);
    if (error) {
      logger.error({ err: error }, 'HTTP server failed to close');
      process.exit(1);
    }

    logger.info('Graceful shutdown complete');
    process.exit(exitCode);
  });
}

server.on('error', (error) => {
  logger.fatal({ err: error }, 'HTTP server failed');
  if (!server.listening) {
    process.exit(1);
  }
  shutdown('server-error', 1);
});

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('uncaughtException', (error) => {
  logger.fatal({ err: error }, 'Uncaught exception');
  shutdown('uncaughtException', 1);
});
process.on('unhandledRejection', (reason) => {
  logger.fatal({ err: reason }, 'Unhandled rejection');
  shutdown('unhandledRejection', 1);
});
