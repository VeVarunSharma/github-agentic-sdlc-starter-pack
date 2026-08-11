# ADR 0002: Annotated enterprise governance source

**Status:** Accepted
**Date:** 2026-08-09
**Owners:** Enterprise AI administrators and developer experience

## Context

GitHub consumes centralized Copilot settings from strict JSON in a selected
organization `.github-private` repository. Enterprise administrators also need
setting-level rationale, client support, precedence, security effect, rollout,
and ownership to remain reviewable next to each value. Strict JSON cannot carry
that documentation.

The starter repository is an application template and cannot itself become or
select an enterprise governance repository.

## Decision

Maintain annotated JSONC as the canonical policy source under
[`examples/enterprise-governance/`](../../examples/enterprise-governance/) and
commit deterministic generated strict JSON beside it. A dependency-free Node 22
renderer validates explicit enterprise, organization, repository, and telemetry
inputs; a validator blocks undocumented keys, unsupported inventory, unsafe MCP
matchers, unresolved deployment tokens, secrets, schema drift, and byte drift.

The overlay root mirrors the future `.github-private` repository root so
administrators copy its contents directly. Activation remains an explicit
administrator action after preview, review, protection, and pilot validation.

## Consequences

- Reviewers can assess policy intent without weakening GitHub's strict JSON
  contract.
- Generated files are never hand-edited; normal CI detects drift.
- Client-support claims are dated evidence and must be refreshed as GitHub
  changes preview or GA behavior.
- Repository-local agent primitives and enterprise-managed policy remain
  separate trust and release boundaries.
- Adopters must render their own identifiers and select the copied governance
  source before any enterprise enforcement exists.
