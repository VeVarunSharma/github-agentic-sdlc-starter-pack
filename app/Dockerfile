# syntax=docker/dockerfile:1.18

FROM node:26-slim@sha256:c0753125a3789977aefe869cbebccf70e3cfd7ea84ca48547458f02e4f1d7146 AS dependencies
WORKDIR /app

ARG NPM_CONFIG_REGISTRY
ARG NPM_CONFIG_REPLACE_REGISTRY_HOST=never

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund \
    && npm cache clean --force

FROM node:26-slim@sha256:c0753125a3789977aefe869cbebccf70e3cfd7ea84ca48547458f02e4f1d7146 AS runtime
WORKDIR /app

ARG BUILD_SHA
ARG BUILD_TIME
ARG GITHUB_REPOSITORY

ENV NODE_ENV=production \
    PORT=3000 \
    BUILD_SHA=${BUILD_SHA} \
    BUILD_TIME=${BUILD_TIME} \
    GITHUB_REPOSITORY=${GITHUB_REPOSITORY}

COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json package-lock.json ./
COPY --chown=node:node public ./public
COPY --chown=node:node src ./src

# npm is required only in the dependency stage. Removing it from runtime
# eliminates package-manager code and its transitive attack surface.
RUN rm -rf /usr/local/lib/node_modules/npm \
    && rm -f /usr/local/bin/npm /usr/local/bin/npx

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "--input-type=module", "-e", "const response = await fetch(`http://127.0.0.1:${process.env.PORT}/health`); process.exit(response.ok ? 0 : 1);"]

CMD ["node", "--import", "@azure/monitor-opentelemetry/loader", "--import", "./src/telemetry.js", "./src/server.js"]
