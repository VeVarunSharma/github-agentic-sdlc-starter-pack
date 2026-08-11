# Sample app — agentic SDLC control plane

Node.js 22 + Express 5 deploy target for the **GitHub Agentic SDLC Starter
Pack**. The framework-free UI shows the issue → agent → PR/gates → review →
merge → deploy loop and reads live runtime evidence from the same container.

Root [`DESIGN.md`](../DESIGN.md) is the enforceable visual source for
`public/**`.

## Endpoints

| Method | Path | Response |
| --- | --- | --- |
| `GET` | `/` | Responsive semantic HTML control-plane showcase |
| `GET` | `/api/info` | `{ name, version, build, runtime }` with allowlisted metadata |
| `GET` | `/health` | `{ status: "ok", uptime }` for liveness and deployment probes |

`/health` remains backward compatible and both JSON endpoints send
`Cache-Control: no-store`. Static CSS and JavaScript are same-origin assets
with bounded caching.

## Structure

```text
src/app.js                 Express app factory
src/server.js              listen + graceful signal shutdown
src/telemetry.js           Azure Monitor preload
src/routes/                thin HTTP routes
src/services/              response/business logic
src/lib/                   environment, logger, errors
src/middleware/            request IDs, 404, central errors
public/                    HTML, CSS, browser ESM
```

## Run locally

```bash
npm ci
npm start
curl http://localhost:3000/
curl http://localhost:3000/api/info
curl http://localhost:3000/health
```

Environment is parsed with Zod at startup:

| Variable | Default | Purpose |
| --- | --- | --- |
| `NODE_ENV` | `development` | Runtime mode |
| `PORT` | `3000` | HTTP listen port |
| `LOG_LEVEL` | `info` | Pino level |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | unset | Azure Monitor export target |
| `BUILD_SHA`, `BUILD_TIME`, `GITHUB_REPOSITORY` | unset | Safe `/api/info` metadata |

Telemetry uses
[`@azure/monitor-opentelemetry`](https://learn.microsoft.com/javascript/api/overview/azure/monitor-opentelemetry-readme)
with Node's ESM loader and a preload before Express/HTTP imports. A missing
connection string is an explicit local no-op. If a connection string is
configured and Azure Monitor initialization fails, startup fails visibly.
No instrumentation key or client secret is supported.

## Validate

```bash
npm ci
npm run lint
npm test
npm audit --omit=dev --audit-level=high
```

Tests use `node:test` + Supertest against `createApp()`, never a live server.
They cover HTML/accessibility structure, APIs, security headers, caching,
request IDs, 404s, body limits, malformed JSON, and error redaction.

## Build and run the container

```bash
docker build -t agentic-sdlc-sample-app .
docker run --rm -p 3000:3000 agentic-sdlc-sample-app
```

Enterprise package mirrors can be selected without changing the lock file;
integrity hashes remain enforced. Use a credential-free URL; build arguments
can appear in build metadata.

```bash
docker build \
  --build-arg NPM_CONFIG_REGISTRY=https://<approved-mirror>/npm/ \
  --build-arg NPM_CONFIG_REPLACE_REGISTRY_HOST=always \
  -t agentic-sdlc-sample-app .
```

The multi-stage image pins `node:22-bookworm-slim` by immutable multi-platform
digest, installs only production dependencies, copies only runtime files, runs
as the non-root `node` user, and uses native `fetch` for its `HEALTHCHECK`.
