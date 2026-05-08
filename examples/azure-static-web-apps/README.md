# Example: Azure Static Web Apps (SPA + optional Functions API)

> A focused **delta** from the root baseline. This example replaces the
> App Service Containers approach (Node API + Docker + ACR) with
> [Azure Static Web Apps (SWA)][swa-docs] for SPAs / JAMstack workloads.

## Overview

[Azure Static Web Apps][swa-docs] is a Microsoft-managed hosting service that
serves static front-end assets from a global CDN edge and (optionally) runs a
co-located Azure Functions HTTP API under the same origin. It's purpose-built
for SPAs (React, Vue, Svelte, Astro, statically-exported Next.js) and
JAMstack sites, and includes per-PR preview environments, free TLS, custom
domains, and built-in auth providers.

This example swaps out the baseline's App Service + ACR + Dockerfile pipeline
in favor of an SWA resource and the
[`Azure/static-web-apps-deploy@v1`][swa-action] action. The OIDC bootstrap
remains identical — you still federate a managed identity to GitHub for the
Terraform plan/apply, but the **SPA deployment itself** uses an API token
that SWA mints (output by Terraform → stored as a repo secret). An OIDC-only
alternative using the `swa` CLI is documented below.

## When to use this example

- You're shipping a SPA (React / Vue / Svelte / Astro / Next-static).
- You want global CDN edge caching out of the box.
- You want a preview environment per pull request.
- Your API surface is modest — a handful of HTTP endpoints that fit
  Azure Functions, **or** you have a separate API hosted elsewhere.
- You want managed TLS, custom domains, and built-in auth providers
  (GitHub, Microsoft Entra, etc.) without standing up an identity layer.

## When NOT to use this example

- **Long-lived backend services** (websockets, background workers, pinned
  connection pools) → use the root **App Service Containers** baseline.
- **Server-side rendering** with a custom Node runtime (e.g. Next.js SSR,
  Remix, Nuxt SSR) → use the **Container Apps** sibling example.
- **Complex backend** with more than a handful of endpoints, heavy
  middleware, or non-HTTP triggers → use App Service or Container Apps.
- **Workloads that need VNet integration for the front-end tier**.
  SWA's managed Functions support VNet integration only on the dedicated
  plan; if you need it broadly, prefer App Service.

## Delta from baseline

- **REPLACES** `infra/app/main.tf` resources (App Service Plan + Linux Web
  App + ACR) with an `azurerm_static_web_app` resource.
- **REPLACES** `.github/workflows/azure-deploy.yml` with a workflow built
  around `Azure/static-web-apps-deploy@v1`.
- **REMOVES** the `Dockerfile` and the ACR build/push steps entirely.
- **REMOVES** the `app/` Express server.
- **ADDS** `web/` (the static SPA) and (optionally) `api/` (the Functions
  API co-deployed by SWA).
- **ADDS** `staticwebapp.config.json` for routing, fallback, and headers.
- **UNCHANGED**: the `infra/bootstrap/` module — you still need a deploy
  managed identity and federated credential for Terraform itself. Only the
  *application deploy* mechanism changes.

## Files in this example

| Path                                          | Purpose                                              |
| --------------------------------------------- | ---------------------------------------------------- |
| `infra/app/main.tf`                           | Static Web App + Application Insights + Log Analytics|
| `.github/workflows/azure-deploy.yml`          | Build + deploy workflow (incl. PR preview cleanup)   |
| `web/index.html`                              | Minimal dependency-free SPA                          |
| `staticwebapp.config.json`                    | Routing, SPA fallback, security headers              |
| `api/host.json`                               | Functions host config                                |
| `api/package.json`                            | Functions runtime metadata (no deps)                 |
| `api/health/function.json`                    | HTTP trigger binding for `/api/health`               |
| `api/health/index.js`                         | `/api/health` handler                                |

## How to apply this example to a fresh template instantiation

1. **Swap the Terraform app module:**
   ```sh
   cp examples/azure-static-web-apps/infra/app/main.tf infra/app/main.tf
   ```

2. **Swap the deploy workflow:**
   ```sh
   cp examples/azure-static-web-apps/.github/workflows/azure-deploy.yml \
      .github/workflows/azure-deploy.yml
   ```

3. **Replace the sample app:**
   ```sh
   rm -rf app/ Dockerfile
   cp -R examples/azure-static-web-apps/web ./web
   cp -R examples/azure-static-web-apps/api ./api
   cp examples/azure-static-web-apps/staticwebapp.config.json ./staticwebapp.config.json
   ```

4. **Update `.github/dependabot.yml`** (in the consuming repo):
   - Remove the `npm` ecosystem entry pointing at `app/`.
   - Remove the `docker` ecosystem entry pointing at `app/`.
   - Add an `npm` entry for `/api` if you keep the Functions API.
   - The static `web/` folder has no package manifest, so no entry is needed.

5. **Surface the SWA deployment token from `infra/bootstrap`** (or wherever
   you wire repo secrets):
   - The `azurerm_static_web_app` resource exposes `api_key` (the deployment
     token). Pipe that into the GitHub repo secret
     `AZURE_STATIC_WEB_APPS_API_TOKEN`. With the `github` provider this is a
     two-line `github_actions_secret`.
   - **Alternative:** stay token-free by using the `swa` CLI under
     `azure/login@v2` (OIDC). See the comments in
     `.github/workflows/azure-deploy.yml`. This is more secure (no
     long-lived secret) but loses the built-in PR preview lifecycle that
     `static-web-apps-deploy@v1` gives you.

6. **Re-run the bootstrap apply** if you renamed any resources, then
   `terraform -chdir=infra/app apply`.

## Local development

The included `web/` SPA is dependency-free — open `web/index.html` directly,
or run any static file server. To exercise the Functions API locally with
the same routing as SWA, install the [SWA CLI][swa-cli]:

```sh
npm install -g @azure/static-web-apps-cli
swa start web --api-location api
```

This serves the SPA and proxies `/api/*` to the local Functions runtime,
mirroring the production routing rules in `staticwebapp.config.json`.

## References

- [Azure Static Web Apps documentation][swa-docs]
- [`Azure/static-web-apps-deploy` GitHub Action][swa-action]
- [`staticwebapp.config.json` schema reference][swa-config]
- [`azurerm_static_web_app` Terraform resource][swa-tf]
- [Static Web Apps CLI (`swa`)][swa-cli]
- [Functions in Static Web Apps (managed)][swa-functions]

[swa-docs]: https://learn.microsoft.com/azure/static-web-apps/overview
[swa-action]: https://github.com/Azure/static-web-apps-deploy
[swa-config]: https://learn.microsoft.com/azure/static-web-apps/configuration
[swa-tf]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/static_web_app
[swa-cli]: https://github.com/Azure/static-web-apps-cli
[swa-functions]: https://learn.microsoft.com/azure/static-web-apps/apis-functions
