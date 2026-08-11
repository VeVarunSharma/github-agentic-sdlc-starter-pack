import { useAzureMonitor } from '@azure/monitor-opentelemetry';
import { resourceFromAttributes } from '@opentelemetry/resources';

import packageJson from '../package.json' with { type: 'json' };
import { env } from './lib/env.js';

export function initializeTelemetry(environment = env) {
  const connectionString =
    environment.APPLICATIONINSIGHTS_CONNECTION_STRING;

  if (!connectionString) {
    return false;
  }

  useAzureMonitor({
    azureMonitorExporterOptions: {
      connectionString,
    },
    resource: resourceFromAttributes({
      'service.name': packageJson.name,
      'service.namespace': 'github-agentic-sdlc-starter-pack',
      'service.version': packageJson.version,
    }),
  });

  return true;
}

export const telemetryEnabled = initializeTelemetry();
