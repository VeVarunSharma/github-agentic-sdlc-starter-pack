# Deployment Plan

## Status

Validated

## Scope

Modernize the existing Node.js 22 sample app, add Azure Monitor
OpenTelemetry instrumentation, harden its container and CI supply chain, and
make Azure App Service deployments immutable and rollback-safe with an
optional staging-slot path.

## Constraints

- Build only stack layer 3 on commit `cc59c364e268bb5cd26a7546c6942d07d145b7c7`.
- Preserve the Layer 2 OIDC identities and least-privilege role scopes.
- Keep the default deployment compatible with the low-cost B1 plan.
- Do not execute an Azure deployment from this task.

## Approved Work

The parent session supplied the exact implementation scope, validation gates,
base branch, and dependent-PR requirement. That delegated scope is the
approval to proceed in autopilot mode.

## Planned Phases

1. Inventory the current app, infrastructure, workflows, and documentation.
2. Implement the Node.js ESM app, telemetry preload, tests, and showcase UI.
3. Harden the container and CI image-scanning gates.
4. Add digest deployment, direct rollback, and optional slot deployment.
5. Add validated optional staging-slot Terraform resources.
6. Update directly related documentation and repository checks.
7. Run local app, container, workflow, Terraform, repository, and APM
   validation.
8. Commit, push, open a dependent PR, and resolve checks introduced here.

## Architecture Decisions

- Run the Node.js app as ESM with Azure Monitor's ESM loader and a dedicated
  telemetry preload before `server.js` imports Express or `node:http`.
- Treat a missing Application Insights connection string as an intentional
  local/no-telemetry mode; allow configured initialization errors to terminate
  startup.
- Keep the default B1 deployment direct and rollback to the exact captured
  `linuxFxVersion`. Enable slots only through an explicit repository variable
  and Terraform input on Standard, Premium, or Isolated plans.
- Give the optional slot its own system identity and registry-scoped
  `AcrPull`; retain the Layer 2 deploy identity and parent-Web-App role scope.
- Build one SHA-tagged image for inventory, deploy its pushed OCI digest, and
  retain BuildKit provenance and SBOM attestations.
- Add immutable Hadolint and Trivy action pins. Trivy blocks fixed
  HIGH/CRITICAL image findings and documents the intentional
  `ignore-unfixed` policy.

## Validation Steps

- [x] Node.js clean install, lint, `node:test`, and production audit.
- [x] Local startup and `/`, `/api/info`, `/health` endpoint smoke.
- [x] Invalid configured telemetry fails startup visibly.
- [x] Desktop and 390px mobile Playwright/browser rendering review.
- [x] Pinned Docker build, running HEALTHCHECK, and endpoint smoke.
- [x] Hadolint error-threshold policy.
- [x] Trivy fixed HIGH/CRITICAL policy with `ignore-unfixed`.
- [x] Terraform format/init/validate for bootstrap, app, and inherited example.
- [x] Terraform mock-plan tests for B1 direct, S1 slot, and B1 rejection.
- [x] Actionlint, ShellCheck, JSON, ruleset, lockfile, and OIDC validators.
- [x] APM install/frozen replay/audit with no managed-file drift.
- [x] Static RBAC review for Web App, slot, deploy, plan, and apply identities.

## Role Assignment Verification

- Status: Verified.
- Web App identity: `AcrPull` on the exact ACR.
- Optional slot identity: distinct system principal with its own `AcrPull` on
  the exact ACR.
- Deploy identity: unchanged Layer 2 `AcrPush` + `Reader` on the exact ACR and
  `Website Contributor` on the exact parent Web App.
- Plan/apply identities: unchanged Layer 2 scopes and separation.
- No role was broadened to the workload resource group or subscription.

## Section 7: Validation Proof

- `NPM_CONFIG_REGISTRY=<approved-mirror> NPM_CONFIG_REPLACE_REGISTRY_HOST=always ./scripts/verify.sh --strict`
  passed every app, Terraform matrix, repository, Docker, and APM check with
  zero skips.
- `docker run ... hadolint --failure-threshold error - < app/Dockerfile`
  passed; the only informational finding is use of the official image's
  non-root named `node` user.
- `docker run ... trivy image --exit-code 1 --ignore-unfixed --severity
  HIGH,CRITICAL --scanners vuln agentic-sdlc-sample-app:layer3` passed after
  removing npm from the runtime stage.
- `terraform -chdir=infra/app test -no-color` passed all 3 mock-plan tests.
- Playwright/browser captures were reviewed at 1440px desktop and 390px mobile
  widths; no horizontal overflow or clipped interactive controls remained.
- A configured invalid Application Insights connection string terminated
  startup with a nonzero exit; no configured telemetry failure was converted
  into application success.

An Azure deployment was intentionally not executed: this layer prepares and
validates code/workflows only, and its delegated scope requires a dependent PR
rather than mutating live Azure resources.
