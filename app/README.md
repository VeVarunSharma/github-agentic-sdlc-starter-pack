# Sample App — Deploy Target

Minimal Node/Express service used as the deploy target for the **GitHub Agentic
SDLC Starter Pack**. This app is intentionally tiny — its purpose is to
exercise the deploy pipeline end-to-end, not to demo Express features.

## Endpoints

| Method | Path      | Response                                        |
| ------ | --------- | ----------------------------------------------- |
| GET    | `/`       | `{ name, version }` — read from `package.json`  |
| GET    | `/health` | `{ status: "ok", uptime }` — for liveness probe |

## Run locally

```bash
npm install
npm start
# then in another shell:
curl http://localhost:3000/
curl http://localhost:3000/health
```

## Run tests

Uses Node's built-in test runner — no Jest, no supertest.

```bash
npm test
```

## Lint

```bash
npm run lint
```

## Build & run the container

```bash
docker build -t agentic-sdlc-sample-app .
docker run --rm -p 3000:3000 agentic-sdlc-sample-app
```

## Where this fits

- `infra/app/` (sibling directory) provisions the Azure resources this app
  deploys to.
- `.github/workflows/azure-deploy.yml` builds this image, pushes it to the
  registry, and rolls it out.

If you're looking to demo Express, look elsewhere. If you're looking to demo
how Copilot, Actions, and Azure ship code together — this is the payload.
