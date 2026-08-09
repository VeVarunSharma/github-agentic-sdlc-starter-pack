# Quality grades

**Owner:** Engineering maintainers
**Status:** Active
**Last verified:** 2026-08-09

Grades describe current evidence, not aspiration.

| Domain | Grade | Evidence | Next threshold |
| --- | --- | --- | --- |
| App runtime | A | Lint, unit tests, container smoke, Trivy | Maintain without harness regressions |
| Azure delivery | A- | OIDC, scoped identities, saved plan, digest rollback | Exercise disaster recovery |
| Agent context | A- | Canonical map, narrow instructions, harness checks | Multi-client conformance fixtures |
| Documentation | B+ | Catalog, link/anchor checks, ADRs/plans | Automated freshness ownership reminders |
| Hooks | B+ | v1 schema, Bash fixtures, PowerShell adapter | Execute fixtures on Windows CI |
| MCP | B+ | Cloud allowlists, built-in server awareness, exact local pin | Scheduled reviewed pin refresh |
| APM supply chain | A- | Commit pins, lockfile, frozen install, audit | Signed upstream package policy |

Grade changes require a linked evidence change in code, tests, CI, or an ADR.
