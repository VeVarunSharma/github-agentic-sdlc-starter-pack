# APM ownership model

The repo uses a **layered ownership model**. Knowing which files are
hand-authored vs which APM owns is essential because:

- APM **rewrites** the files it owns on every `apm install`.
- The CI audit (`.github/workflows/apm-audit.yml`) detects drift in
  APM-managed files.
- Hand-authored files are tolerated by APM as "unmanaged" thanks to
  `unmanaged_files.action: warn` in `apm-policy.yml`.

## Ownership table

| Path | Owner | Notes |
|------|-------|-------|
| `.github/copilot-instructions.md` | **Hand-authored** | Primary agent context. **Never** run `apm compile -t copilot` — it would clobber this file. |
| `AGENTS.md` | **Hand-authored** | Slim pointer back to `.github/copilot-instructions.md`. |
| `.github/instructions/app-nodejs.instructions.md` | **Hand-authored** | Path-scoped guidance for the sample app. |
| `.github/instructions/infra-terraform.instructions.md` | **Hand-authored** | Path-scoped guidance for Terraform. |
| `.github/instructions/<all other *.instructions.md>` | **APM** | Pinned in `apm.yml`; rewritten on `apm install`. |
| `.github/prompts/*.prompt.md` | **Hand-authored** | This repo currently ships only hand-authored prompts. |
| `.github/chatmodes/*.chatmode.md` | **Hand-authored** | awesome-copilot ships zero chatmodes today. APM v0.12.4 routes `.chatmode.md` files into `.github/agents/`, but VS Code 1.100+ reads from `.github/chatmodes/`. We hand-author into the VS Code path. |
| `.github/agents/*.agent.md` | **Hand-authored** | This repo currently ships one hand-authored example. |
| `.github/skills/oidc-rotation/` | **Hand-authored** | This repo's own skill. |
| `.github/skills/review-and-refactor/` | **APM** | From `github/awesome-copilot`. |
| `.github/hooks/*.json` | **Hand-authored** | |
| `.github/mcp/mcp.json` | **Hand-authored** | |
| `apm.yml`, `apm-policy.yml` | **Hand-authored** | Manifest + policy. Edit by hand to add/remove deps. |
| `apm.lock.yaml` | **APM** | Committed but rewritten by `apm install`. Treat like `package-lock.json`: don't hand-edit, but do commit changes. |
| Everything in `app/`, `infra/`, `examples/`, `scripts/`, `docs/`, root community files | **Hand-authored** | Repo-owned. APM never touches these. |

Each hand-authored primitive starts with an `<!-- HAND-AUTHORED -->`
marker so it's easy to tell at a glance what is generated and what is not.

## Conflict resolution

| Scenario | Resolution |
|----------|------------|
| You edit an APM-managed file by hand | The next `apm install` overwrites your edit. Move your change into `apm.yml` (re-pin the dep at a fork or different version) or into a hand-authored file alongside it. |
| You add a hand-authored file with the same name as one in `apm.yml` | `apm install` refuses to overwrite a file it doesn't already own. Resolve by renaming yours, or by removing the dep from `apm.yml`. |
| You want to fork an APM-installed file | Copy it to a new filename, add `<!-- HAND-AUTHORED -->`, edit freely. The APM-owned original remains. |
| `apm install --force` | **Forces** APM to overwrite hand-authored files that have the same paths it would emit. We do **not** use `--force` in CI. Document any local use. |

## Audit behaviour

`apm-policy.yml` sets:

```yaml
unmanaged_files:
  action: warn   # not "error"
```

That's deliberate. The audit (`.github/workflows/apm-audit.yml`) runs:

```bash
apm install --target copilot
apm audit --ci --policy ./apm-policy.yml
```

It does **not** run `apm compile -t copilot` because that command would
overwrite `.github/copilot-instructions.md`. The audit:

1. Re-runs `apm install` and verifies no APM-owned file drifted.
2. Verifies hand-authored files are present in the "unmanaged" report
   (warnings only — never failures).
3. Uploads the SARIF report so findings appear in the Security tab.

## Why we commit APM-installed files

We could `.gitignore` them and run `apm install` on every PR. We don't,
because:

- New consumers see a working `.github/` on first clone without needing
  to install APM.
- The diff is reviewable in PRs (a transparent record of what
  awesome-copilot ships).
- The `apm-audit.yml` gate detects local drift from the locked APM
  resolution. (For freshness against upstream we use the weekly
  `apm-update.yml` PR cadence — see
  [`maintenance-matrix.md`](./maintenance-matrix.md).)

Trade-off: APM-installed files show up in the diff. We accept that for
the transparency benefit.
