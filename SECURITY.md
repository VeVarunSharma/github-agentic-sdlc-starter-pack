# Security Policy

## Supported versions

This is a **starter pack / template** repo, not a deployed service —
the artifact is the contents of `main`. We address security issues on:

| Branch | Status |
| --- | --- |
| `main` | ✅ Active — patches land here first |
| Forks / template instances | ⚠️ Out of scope — re-apply the patch from upstream |

If you've used this template to bootstrap a downstream repo, the
**downstream owner is responsible** for backporting security fixes.
Watch this repo (Releases only) to get notified when a security fix
ships.

## Reporting a vulnerability

**Please do NOT open a public GitHub issue for security findings.**

Use **GitHub Private Vulnerability Reporting**:
👉 [Open a private advisory](../../security/advisories/new)

If you cannot use GitHub PVR, email **<security-contact-email>** with:

- A short description of the issue
- Steps to reproduce
- Affected files / commit SHA
- Your assessment of impact (confidentiality / integrity / availability)
- Whether you'd like public credit when the advisory is published

We aim to acknowledge reports within **2 business days** and to ship a
fix or mitigation within **30 days** for high/critical severity. Lower
severities are best-effort.

## Scope

In scope for this repo:

- The sample Node.js application in `app/`
- The Terraform modules in `infra/bootstrap/` and `infra/app/`
- The GitHub Actions workflows under `.github/workflows/`
- The branch ruleset JSON under `.github/rulesets/`
- The APM manifest, policy, and lockfile (`apm.yml`,
  `apm-policy.yml`, `apm.lock.yaml`)
- The setup scripts under `scripts/`

Out of scope:

- Vulnerabilities in upstream dependencies — please report those to
  the dependency's own security contact. We will, however, prioritise
  bumping the pin once a fix is available upstream.
- Vulnerabilities in `examples/*` variants (we accept reports but the
  fix priority is lower than for the baseline).
- Vulnerabilities in agent-installed APM dependencies — report
  upstream and open an issue here so we can pin to a fixed version.

## Hardening baseline already in place

This template ships with the following security controls **enabled by
default**:

| Control | Where |
| --- | --- |
| GitHub Advanced Security baseline (CodeQL, Dependabot, Dependency Review, Secret Scanning, Push Protection) | `.github/workflows/codeql.yml`, `.github/dependabot.yml`, `.github/workflows/dependency-review.yml`, repo settings |
| OIDC-based Azure deploy (no long-lived credentials) | `infra/bootstrap/`, `.github/workflows/azure-deploy.yml` |
| APM dependency policy + content scanning | `apm-policy.yml`, `.github/workflows/apm-audit.yml` |
| Pinned Action SHAs / major versions, weekly Dependabot for `github-actions` | `.github/dependabot.yml` |
| Branch protection rulesets-as-code | `.github/rulesets/` |
| GitHub Environment gate for production deploys | `azure-deploy.yml` (`environment: production`) |
| Container runs as non-root user | `app/Dockerfile` |

For additional hardening (signed commits, OpenSSF Scorecard,
CLA-Assistant, etc.), see
[`examples/public-oss-hardening/`](./examples/public-oss-hardening/)
once the variant is published, and
[`docs/enterprise-hardening.md`](./docs/enterprise-hardening.md).

## Responsible disclosure

We follow [coordinated disclosure](https://www.first.org/global/sigs/vulnerability-coordination/multiparty/guidelines).
Please give us a reasonable window (usually 30–90 days) to ship a fix
before publicising the issue. We will credit reporters in the
advisory unless they request anonymity.

Thank you for helping keep this project — and the orgs that adopt
it — safe.
