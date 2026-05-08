# Allstar opt-in

> [Allstar][allstar] is an OpenSSF GitHub App that **continuously
> enforces security policies** on repos and orgs. Unlike GitHub-native
> rulesets (which check at push/PR time), Allstar runs on a schedule
> and either alerts via issues, or auto-corrects drift.
>
> Allstar is **org-scoped** — you (or an org admin) install it once
> per org, then opt repos in by configuration files, not workflows.
> That's why it's a `.md` opt-in doc here, not a workflow.

## Why Allstar in addition to rulesets?

| Concern                                     | Rulesets cover it? | Allstar covers it? |
| ------------------------------------------- | ------------------ | ------------------ |
| Branch protection (push, force-push)        | ✅                 | ✅ (drift detect)  |
| Required checks                             | ✅                 | —                  |
| Required signed commits                     | ✅                 | —                  |
| Repo settings (delete branches on merge)    | —                  | ✅                  |
| Outside collaborators with admin            | —                  | ✅                  |
| `SECURITY.md` exists                        | —                  | ✅                  |
| Binary artifacts in source                  | —                  | ✅                  |
| GitHub Actions allowlist                    | —                  | ✅                  |

The two are complementary: rulesets enforce at push time; Allstar
detects drift in repo *settings* and ambient state on a schedule.

## Step 1 — Install the Allstar App on the org

An **org admin** must install [Allstar][allstar-install] on the
GitHub organization. Choose the install scope:

- **All repos** (recommended once you trust the policies)
- **Selected repos** (start here while piloting)

Once installed, Allstar creates a private `.allstar` repo in the org
that holds org-wide config.

## Step 2 — Opt this repo in

Allstar uses an **opt-in by default** model. To enable it for this
repo without changing the org-wide default:

```bash
# In this repo:
mkdir -p .allstar
cat > .allstar/allstar.yaml <<'YAML'
optConfig:
  optIn: true
YAML

git add .allstar/allstar.yaml
git commit -s -m "chore(security): opt in to Allstar policies"
```

## Step 3 — Per-policy config

Each Allstar policy reads its own config file in `.allstar/`. Sensible
defaults that pair with this template's posture:

`.allstar/branch_protection.yaml`:
```yaml
optConfig:
  optIn: true
action: issue   # 'issue' files an issue on drift; 'log' is silent; 'fix' auto-corrects
requireApproval: true
requireCodeOwnerReviews: true
requireStatusChecks: true
dismissStaleReviews: true
blockForcePush: true
requireSignedCommits: true   # matches main-branch-oss-hardening.json
enforceOnAdmins: true
```

`.allstar/binary_artifacts.yaml`:
```yaml
optConfig:
  optIn: true
action: issue
```

`.allstar/outside.yaml`:
```yaml
optConfig:
  optIn: true
action: issue
allowOutsideAdmin: false
allowOutsidePush: false
```

`.allstar/security.yaml`:
```yaml
optConfig:
  optIn: true
action: issue   # alerts if SECURITY.md is missing/stub
```

`.allstar/scorecard.yaml`:
```yaml
optConfig:
  optIn: true
action: issue
threshold: 7    # alert if OpenSSF Scorecard score drops below 7/10
```

`.allstar/actions.yaml` (workflow allowlist):
```yaml
optConfig:
  optIn: true
action: issue
# Only allow Actions from these owners. Pinning by SHA in workflows
# is still your responsibility.
allowed:
  - actions/*
  - github/*
  - azure/*
  - docker/*
  - hashicorp/*
  - microsoft/*
  - ossf/*
```

## Step 4 — Tune `action:` levels

- **`log`** — silent; Allstar evaluates but does nothing visible.
  Good for a 2-week dry run.
- **`issue`** — files a GitHub Issue on each drift detection. **Default
  recommendation** for production repos.
- **`fix`** — Allstar attempts to auto-correct drift. Use sparingly;
  most policies don't have a safe auto-correct path.

## Step 5 — Verify

After the next Allstar scan (runs ~hourly), expect either:

- **No issues** — your repo already complies.
- **One or more issues** opened by `allstar-app[bot]` describing
  exactly which control is non-compliant and the remediation.

## What this overlay does NOT do

- It doesn't install the App for you (org admin step, manual).
- It doesn't auto-create the org's `.allstar` repo (Allstar handles
  that on first install).
- It doesn't replace the rulesets — keep the
  `main-branch-oss-hardening.json` ruleset as the at-push-time
  enforcement layer; Allstar is the drift-detection layer.

[allstar]: https://github.com/ossf/allstar
[allstar-install]: https://github.com/ossf/allstar#installation-options
