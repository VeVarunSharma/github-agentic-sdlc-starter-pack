# Variant: Public OSS Hardening overlay

> An **overlay** for projects that intend to publish this template as a
> public open-source repository. Adds the controls that public-OSS
> consumers (and their security teams) expect: DCO sign-off
> enforcement, OpenSSF Scorecard, an enforce-mode ruleset that
> requires signed commits, and Allstar opt-in instructions.

This is a **delta** — drop these files in alongside the baseline. No
infrastructure or sample-app code changes.

## When to apply this overlay

Apply if **any** of these is true:

- The repo is, or will be, **public** on github.com.
- You're publishing for **community contribution** (external PRs).
- You need an **OpenSSF Scorecard score** for adoption / governance
  (e.g. listing in [Best Practices Badge][openssf-bp]).
- Your security review requires **DCO** (Developer Certificate of
  Origin) sign-off on every commit.
- Your security review requires **signed commits** on `main`.

Skip if the repo will stay private, internal, or single-team — the
baseline already gives you GHAS, branch protection, OIDC, and CodeQL
without these extra friction points.

## What the overlay adds vs. the baseline

| Control                          | Baseline | Overlay                                                |
| -------------------------------- | -------- | ------------------------------------------------------ |
| DCO sign-off (`Signed-off-by:`)  | Encouraged in CONTRIBUTING.md only | **Required** by `dco.yml` workflow |
| OpenSSF Scorecard                | —        | Weekly scan + SARIF upload + badge                     |
| Signed commits on `main`         | —        | Required by `main-branch-oss-hardening.json` ruleset   |
| [Allstar][allstar] policies      | —        | Opt-in instructions in [`ALLSTAR.md`](./ALLSTAR.md)    |
| Code Coverage as required check  | —        | (Optional — wire your coverage reporter in `dco.yml`'s pattern) |

## Trade-off: signed commits and the Copilot coding agent

> **The GitHub Copilot coding agent does not currently sign its
> commits.** Requiring `required_signatures` on `main` will block
> Copilot-authored PRs from being merged via the agent's own workflow.
>
> Mitigation: **squash-merge** PRs from a maintainer's terminal (which
> signs the squash commit), not from the agent's own merge flow. The
> agent still authors the PR; the maintainer's signed squash carries
> authorship via the `Co-authored-by:` trailer.
>
> See [`docs/enterprise-hardening.md`](../../docs/enterprise-hardening.md)
> for the full discussion.

## How to apply

1. **Copy the workflow files** into the baseline:

   ```bash
   cp examples/public-oss-hardening/.github/workflows/*.yml \
      .github/workflows/
   ```

2. **Copy the overlay ruleset** alongside the baseline rulesets:

   ```bash
   cp examples/public-oss-hardening/.github/rulesets/main-branch-oss-hardening.json \
      .github/rulesets/
   ```

3. **Apply the overlay ruleset.** This **replaces** the baseline
   `main-branch-enforce.json` — they target the same branch with
   conflicting strictness:

   ```bash
   # Tear down the baseline enforce ruleset (if previously applied)
   gh api /repos/<owner>/<repo>/rulesets \
     | jq '.[] | select(.name == "main — enforce") | .id' \
     | xargs -I{} gh api -X DELETE /repos/<owner>/<repo>/rulesets/{}

   # Apply the OSS-hardening overlay
   gh api -X POST /repos/<owner>/<repo>/rulesets \
     --input .github/rulesets/main-branch-oss-hardening.json
   ```

4. **Add the Scorecard badge to README**:

   ```markdown
   [![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/<owner>/<repo>/badge)](https://securityscorecards.dev/viewer/?uri=github.com/<owner>/<repo>)
   ```

5. **Opt in to Allstar** (optional; requires GitHub org admin) — see
   [`ALLSTAR.md`](./ALLSTAR.md).

## What the overlay does not do

- It doesn't change the OIDC bootstrap, ACR, App Service, or any
  baseline workflow. The closed-loop SDLC is unchanged.
- It doesn't add CLA enforcement (DCO only). For CLAs, see
  [cla-assistant.io](https://cla-assistant.io/).
- It doesn't enable the
  [OpenSSF Best Practices badge][openssf-bp] — that's a separate
  application process; this overlay just gives you the Scorecard data
  that backs it.

[openssf-bp]: https://www.bestpractices.dev/
[allstar]: https://github.com/ossf/allstar
