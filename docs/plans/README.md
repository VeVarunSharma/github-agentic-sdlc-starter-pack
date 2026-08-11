# Execution plans

**Owner:** Engineering maintainers
**Status:** Active
**Last verified:** 2026-08-09

Use an ephemeral checklist when work is low risk, single-session, limited to one
domain, and has an obvious rollback. Do not commit that checklist.

Commit an execution plan under `active/` when any of these apply:

- work spans sessions, contributors, or dependent pull requests;
- it changes security, identity, deployment, migration, or public contracts;
- it crosses app, infrastructure, CI, or agent-harness boundaries;
- decisions or verification evidence must survive the implementing session.

Copy [`template.md`](template.md), name it `YYYY-MM-DD-short-name.md`, and keep
scope, progress, decisions, and verification current. A plan is not a status
performance; record failed attempts and changed assumptions.

Move a plan to `completed/` only after its acceptance criteria and verification
are recorded. Abandoned plans stay in `active/` with `Status: Abandoned` until a
maintainer archives them with the reason. Never create fake completed plans.
