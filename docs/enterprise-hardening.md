# Enterprise hardening

The baseline targets a balanced posture suitable for most teams. This
doc describes the additional controls you should layer on for
**regulated, enterprise, or public-OSS** deployments.

For a ready-to-apply OSS overlay see
[`examples/public-oss-hardening/`](../examples/public-oss-hardening/).

## Posture comparison

| Control | Baseline | Public-OSS overlay | Regulated / enterprise |
|---------|----------|--------------------|------------------------|
| Branch protection ruleset | Evaluate-mode default; enforce-mode after graduation | Enforce-mode required signed commits | Enforce-mode + signed commits + required CODEOWNERS review + required deploy environment approval |
| DCO sign-off | Encouraged in `CONTRIBUTING.md`; not enforced | Enforced via DCO-check workflow | Required + audit log retention |
| Signed commits | Off (would break Copilot coding agent loop) | Required (overlay) — accept agent-loop trade-off | Required, plus signed releases |
| Secret scanning | Free tier (public repos) or GHAS (private) | Free / GHAS depending on visibility | GHAS + custom patterns + required-on-org-level |
| OpenSSF Scorecard | Optional add-on | Workflow + badge | Required, score ≥ 7 expected, scheduled cron |
| OpenSSF Allstar | Off | Opt-in instructions in overlay README | Required at org level |
| GHAS Code Scanning | CodeQL via free tier (public) or GHAS (private) | Same | GHAS + multi-language + custom queries + autofix |
| Required-deploy-env approvers | None on `production` (push to main) | Same | At least one human approver on `production` and `infra-apply` |
| Container signing | None | Optional Cosign add-on | Required (Cosign + Sigstore + key-vault-backed key) |
| SBOM | None | Optional Syft add-on | Required (CycloneDX or SPDX, generated per build, signed) |
| Image digest pinning | Tag-based (commit SHA) | Same | Pin by digest in App Service config; rebuild if base image changes |
| Tfstate encryption | Default Azure Storage encryption | Same | Customer-managed keys (CMK) in Key Vault |
| Tfvars secrets | Read from env / not committed | Same | Stored in Key Vault, fetched at apply time via `azurerm_key_vault_secret` data sources |
| Audit log export | GitHub Audit Log retention default (90 days for free) | Same | Stream to SIEM (Splunk, Sentinel) via Audit Log streaming |
| Long-lived branches | Allowed | Allowed | Restricted to `main` + release branches; ephemeral feature branches deleted on merge |

## Compliance-driven additions

### DCO enforcement

Add the DCO check workflow (already in `examples/public-oss-hardening/`):
runs on every PR, verifies every commit has `Signed-off-by:` matching
the PR author. Lightweight (single Action, no third-party app).

### Signed commits + signed tags

Required for regulated. Consequences for the agent loop:

- The GitHub Copilot **cloud coding agent** does not sign its commits
  today. A required-signed-commits ruleset blocks its PRs from merging.
- Workaround: sign the **merge commit** (squash-merge with the
  reviewer's signed key). Document this in PR-template guidance.

### Customer-managed keys for tfstate

```hcl
resource "azurerm_storage_account" "tfstate" {
  # ...
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_key" "tfstate_cmk" {
  name         = "tfstate-cmk"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["wrapKey", "unwrapKey"]
}

resource "azurerm_storage_account_customer_managed_key" "tfstate" {
  storage_account_id = azurerm_storage_account.tfstate.id
  key_vault_id       = azurerm_key_vault.this.id
  key_name           = azurerm_key_vault_key.tfstate_cmk.name
}
```

Rotate the CMK on a documented cadence (e.g. annually).

### SBOM + provenance

Add to `azure-deploy.yml` after the `docker push`:

```yaml
- uses: anchore/sbom-action@v0
  with:
    image: ${{ env.ACR_LOGIN_SERVER }}/${{ vars.AZURE_WEBAPP_NAME }}:${{ github.sha }}
    format: cyclonedx-json
    output-file: sbom.json
- uses: actions/attest-sbom@v2
  with:
    subject-name: ${{ env.ACR_LOGIN_SERVER }}/${{ vars.AZURE_WEBAPP_NAME }}
    subject-digest: ${{ steps.push.outputs.digest }}
    sbom-path: sbom.json
- uses: sigstore/cosign-installer@v3
- run: cosign sign ${{ env.ACR_LOGIN_SERVER }}/${{ vars.AZURE_WEBAPP_NAME }}@${{ steps.push.outputs.digest }} --yes
```

Verify on pull (e.g. via Azure Policy with the
`AllowedContainerImagesRegex` plus a Sigstore validating webhook).

## GHES (GitHub Enterprise Server) considerations

The baseline targets dotcom. On GHES:

- **OIDC issuer URL differs.** The federated credential's issuer is
  `https://token.actions.githubusercontent.com` on dotcom; on GHES it's
  `https://<ghes-host>/_services/token`. Update `infra/bootstrap`'s
  `azuread_application_federated_identity_credential` accordingly.
- **GHAS features** are available on GHES 3.0+ but enabled per repo;
  audit your GHES admin's GHAS license allocation.
- **Awesome-copilot may not be reachable** if GHES Actions runners are
  air-gapped. Mirror to an internal repo and update `apm.yml` paths
  accordingly.
- **Marketplace Actions** require the GHES Actions cache to allow them.
  Use `actions: read` permissions and the GitHub Connect feature where
  possible.

## Audit log streaming

For SOC2 / ISO27001 / FedRAMP / IL5:

- `Settings → Audit log → Streaming` → configure target (Splunk, Azure
  Event Hubs, AWS S3).
- Retention: dotcom Free = 90 days; dotcom Enterprise = 6 months;
  streamed sinks have unbounded retention by default.

## What we do NOT recommend changing in the baseline

- **Allowing direct push to main.** Even with all-other-controls, this
  is the single biggest regression on the agentic SDLC value prop.
- **Disabling secret scanning.** No business case to disable; the cost
  of a leaked credential dwarfs any false-positive friction.
- **Hardcoding secrets in `infra/*/terraform.tfvars`.** Use environment
  variables or Key Vault data sources. Never commit a `terraform.tfvars`
  with secret values; commit only `terraform.tfvars.example`.
