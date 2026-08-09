import packageJson from '../../package.json' with { type: 'json' };

import { env } from '../lib/env.js';

export function getInfo(environment = env) {
  return {
    name: packageJson.name,
    version: packageJson.version,
    build: {
      sha: environment.BUILD_SHA ?? null,
      builtAt: environment.BUILD_TIME ?? null,
      repository: environment.GITHUB_REPOSITORY ?? null,
    },
    runtime: {
      name: process.release.name,
      node: process.version,
      environment: environment.NODE_ENV,
    },
  };
}
