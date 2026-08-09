# Security standard

**Owner:** Security owners
**Status:** Active
**Last verified:** 2026-08-09

## Required controls

- Authenticate GitHub-to-Azure with exact-subject OIDC federation and separate
  plan, apply, and deploy identities.
- Scope RBAC to the smallest resource and never use subscription-wide workflow
  roles or wildcard federation subjects.
- Pin Actions to full SHAs, APM sources to commits, and executable npm packages
  in configuration to exact reviewed versions.
- Treat all app, hook, MCP, model, workflow, and CLI inputs as untrusted.
- Validate before shell/path use; avoid dynamic shell construction entirely.
- Keep cloud MCP tool allowlists explicit and read-only. GitHub and localhost
  Playwright are built in; do not duplicate them.
- Never log or commit secrets, tokens, Terraform state, `.env` files, or PII.
- Preserve secure headers, bounded request bodies, non-root containers, and
  health-verified rollback.

## Escalation

Stop and require human review for privilege expansion, destructive operations,
secret exposure, federation changes, production mutation, or a request to
weaken a gate. Report vulnerabilities through [`../../SECURITY.md`](../../SECURITY.md).

## Evidence

`tools/harness`, app tests, Terraform tests, repository validation, CodeQL,
Dependency Review, secret scanning, APM audit, and the deployment smoke test
form the baseline. Prose alone is not evidence that a control works.
