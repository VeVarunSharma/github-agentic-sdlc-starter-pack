# Plan: Enterprise Copilot governance overlay

**Owner:** Developer experience and enterprise administrators
**Status:** Completed
**Started:** 2026-08-09
**Last updated:** 2026-08-09

## Scope

- Outcome: Add a copy-ready `.github-private` source-of-governance overlay for
  centralized GitHub Copilot settings current through 2026-08-09.
- In scope: Annotated managed settings and team policy sources, deterministic
  generated JSON, enterprise plugin and agents, guarded bootstrap automation,
  governance documentation, ruleset examples, and root harness integration.
- Out of scope: Layer 3 application/runtime/Azure behavior, optional Azure
  variants, production mutation, enterprise creation, real organization data,
  and the Layer 6 evaluation/template-instantiation matrix.
- Acceptance criteria: The overlay renders deterministically from validated
  sample inputs, normal CI detects all policy drift and unsafe matchers, strict
  verification stays green, and the dependent pull request targets the Layer 4
  branch.

## Progress

- [x] Verify the dated GitHub settings inventory and client-support evidence.
- [x] Build and document the complete governance repository overlay.
- [x] Extend the root harness with deterministic overlay validation.
- [x] Integrate the enterprise tier into maintained root documentation.
- [x] Run focused and cross-cutting repository verification.
- [x] Commit, push, open the dependent pull request, and resolve caused checks.

## Decision log

| Date | Decision | Rationale | Consequence |
| --- | --- | --- | --- |
| 2026-08-09 | Keep annotated JSONC canonical and commit generated strict JSON. | GitHub consumes strict JSON while administrators require setting-level rationale. | Drift becomes a blocking deterministic check. |
| 2026-08-09 | Make bootstrap preview-only unless both `--apply` and an exact `--confirm organization/repository` value are supplied. | Enterprise mutation is privileged and must not occur through accidental script execution. | Automation prints reviewable REST operations before execution. |
| 2026-08-09 | Treat the overlay root as the future `.github-private` repository root. | Adopters must be able to copy it without removing a nested wrapper directory. | All paths and links are overlay-relative. |

## Risks and rollback

- Risk: GitHub preview schemas can change after the verification date.
- Mitigation: Check in a dated client-support inventory, official links, strict
  key allowlists, and a periodic review runbook.
- Rollback: Revert this Layer 5 commit or disable selection of the copied
  `.github-private` source; the Layer 3 application and Azure deployment are
  untouched.

## Verification

| Command/check | Expected | Result |
| --- | --- | --- |
| Overlay renderer and `--check` | Four generated JSON files byte-match | Passed |
| Overlay validator and bootstrap safety tests | Policy, schemas, mappings, and no-mutation guarantees pass | 12/12 passed |
| Current Copilot CLI plugin load | Contained plugin is discoverable | Passed with CLI 1.0.79-9 |
| `npm --prefix tools/harness test && npm --prefix tools/harness run validate` | Root harness passes | 10/10 and validation passed |
| `./scripts/validate-repository.sh` | Workflows, shell, JSON, pins, lockfiles, and overlay pass | Passed |
| `./scripts/verify.sh --strict` | Cross-cutting repository verification | App, harness, Terraform, repository, and APM passed locally; local Docker registry TLS reset, while the equivalent clean-network PR Docker gate passed |
| Dependent pull request checks | Layer-caused checks green | All required checks passed, including Docker and CodeQL |
