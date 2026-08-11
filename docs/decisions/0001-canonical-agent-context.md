# ADR-0001: Canonical agent context hierarchy

- **Status:** Accepted
- **Date:** 2026-08-09
- **Owners:** Developer experience

## Context

The repository duplicated extensive project knowledge in
`.github/copilot-instructions.md` while `AGENTS.md` pointed back to it. That
increased prompt cost, drift, and false claims that every client discovered the
same surfaces.

## Decision

Root `AGENTS.md` is the canonical map and stays at or below 120 lines. It holds
invariants, routing, validation, planning, and escalation only. Detailed truth
lives in cataloged docs, matching path instructions, tests, and code.

`.github/copilot-instructions.md` remains a short compatibility bridge that
starts at `../AGENTS.md`. Client-specific adapters are labeled honestly:
VS Code prompt files and handoffs are not portable, repository MCP JSON is a
settings reference rather than auto-discovered configuration, and GitHub's
built-in MCP servers are not duplicated.

## Consequences

- Agents load less irrelevant context and receive deterministic navigation.
- Maintainers must catalog new docs and avoid copying contracts between files.
- `tools/harness` enforces line limits, required sections, links, schemas, and
  ownership.

## Alternatives considered

- Keep Copilot instructions canonical: rejected because native `AGENTS.md`
  support and cross-client portability make the root map the clearer contract.
- Generate one giant instruction file: rejected because generation hides drift
  and defeats progressive disclosure.
