# Review standard

**Owner:** Engineering maintainers
**Status:** Active
**Last verified:** 2026-08-09

## Finding threshold

Report only issues with a concrete execution path and meaningful impact:

- **Blocking:** exploitable vulnerability, correctness/data-loss failure,
  privilege expansion, broken rollback, or a required gate made ineffective.
- **Warning:** likely production failure, missing test for changed behavior, or
  stale contract that would misroute operators or agents.
- Do not report formatting preferences, generic best-practice reminders, or
  pre-existing problems unrelated to the change.

## Finding shape

Every finding names an exact changed line, describes the triggering conditions
and impact, and proposes the smallest safe correction. Group duplicate symptoms
under one root cause.

## Posting and authority

Repository review agents return a report by default. Posting requires explicit
user authorization and a write-capable tool available in that session. No agent
profile in this repository may approve or merge a pull request.
