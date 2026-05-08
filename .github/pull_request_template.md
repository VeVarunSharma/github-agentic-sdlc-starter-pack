# Pull Request

<!--
  Thank you for opening a PR! A few quick conventions:

  * Keep PRs focused — one logical change per PR.
  * Use Conventional Commit prefix in the PR title (becomes the squash
    commit subject): feat | fix | docs | chore | refactor | test | ci | build.
  * Sign your commits with DCO: `git commit -s` (preferred) or check the
    "Signed-off-by" trailer is present.
  * If this PR is fully or partially authored by an AI agent (Copilot
    coding agent, Copilot chat, etc.), check the box below.
-->

## Summary

<!-- What does this PR do, and why? 1–3 sentences. -->

## Linked issue

<!-- Use `Closes #N` to auto-close on merge, or `Refs #N` for a soft link. -->
Closes #

## Type of change

- [ ] feat — new functionality
- [ ] fix — bug fix
- [ ] docs — documentation only
- [ ] chore — tooling / deps / refactor with no behaviour change
- [ ] refactor — code change that neither fixes a bug nor adds a feature
- [ ] test — adding or improving tests
- [ ] ci — CI configuration / workflows
- [ ] build — build system / Dockerfile

## Authorship

- [ ] **Agent-authored** — the diff was produced (in whole or in part) by an AI agent
  - Agent: <!-- e.g. GitHub Copilot coding agent / Copilot chat / Cursor / ... -->
  - Reviewer signed off via DCO trailer: `Signed-off-by: <Name> <email>`
- [ ] Human-authored only

## Checks (gates that must be green)

- [ ] `app — lint + tests` passes
- [ ] `terraform — fmt + validate` passes for any touched module
- [ ] `Analyze (javascript-typescript)` (CodeQL) passes
- [ ] `apm install + audit` passes
- [ ] `Review dependency changes` (Dependency Review) passes
- [ ] PR title follows Conventional Commits

## Risk + rollout

<!--
  Anything operational reviewers should know:
  * Does this change behaviour in production?
  * Does it introduce a new dependency, API, or env var?
  * Is a rollback plan needed (feature flag, fast-forward revert)?
-->

## Screenshots / output

<!-- Optional. Useful for UI changes or new CLI output. -->
