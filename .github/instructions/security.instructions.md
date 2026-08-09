<!-- HAND-AUTHORED - concise security invariants for risk-bearing paths. -->
---
description: "Repository security invariants; deeper rationale lives in docs/standards/security.md"
applyTo: "app/**,infra/**,.github/workflows/**,.github/hooks/**,.github/mcp/**,scripts/**,tools/**"
---

# Security invariants

- Treat request, hook, tool, model, workflow, and MCP data as untrusted input.
- Never interpolate untrusted values into shells, paths, SQL, Terraform
  addresses, workflow expressions, or generated configuration.
- Use OIDC/managed identity and least privilege; never add long-lived cloud
  credentials, broad subscription roles, or wildcard federation subjects.
- Pin Actions to full SHAs and executable packages to exact reviewed versions.
- Keep MCP tools explicitly allowlisted and read-only unless a reviewed use case
  requires mutation. Never configure duplicate built-in GitHub/Playwright MCP.
- Fail closed on malformed policy/configuration and surface actionable errors.
- Do not log secrets, tokens, full request bodies, hook payloads, or PII.
- Follow [`../../docs/standards/security.md`](../../docs/standards/security.md)
  and run the validation routed by [`../../AGENTS.md`](../../AGENTS.md).
