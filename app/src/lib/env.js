import { z } from 'zod';

const optionalString = (maxLength) =>
  z.preprocess(
    (value) =>
      typeof value === 'string' && value.trim() === '' ? undefined : value,
    z.string().trim().min(1).max(maxLength).optional(),
  );

const environmentSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
    .default('info'),
  APPLICATIONINSIGHTS_CONNECTION_STRING: optionalString(4096),
  BUILD_SHA: optionalString(128),
  BUILD_TIME: optionalString(128),
  GITHUB_REPOSITORY: optionalString(256),
});

export function parseEnvironment(source = process.env) {
  const result = environmentSchema.safeParse(source);

  if (!result.success) {
    const details = result.error.issues
      .map(({ path, message }) => `${path.join('.') || 'environment'}: ${message}`)
      .join('; ');
    throw new Error(`Invalid environment configuration: ${details}`);
  }

  return Object.freeze(result.data);
}

export const env = parseEnvironment();
