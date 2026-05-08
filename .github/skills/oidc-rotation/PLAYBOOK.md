<!-- HAND-AUTHORED — playbook for the oidc-rotation skill. -->

# OIDC rotation — playbook

Step-by-step procedure to rotate the Azure federated credential on the
deploy UAMI. Pair this with `SKILL.md` in the same directory.

## 0. Prerequisites

```bash
# Confirm you are logged into the right Azure context.
az account show --query '{tenant:tenantId, subscription:id, name:name}'

# Confirm you can write to the UAMI's federated credentials.
az identity federated-credential list \
  --identity-name "${UAMI_NAME}" \
  --resource-group "${BOOTSTRAP_RG}" \
  --output table
```

If the `az identity federated-credential list` call fails with `403`,
stop here and request the `Contributor` role on `${BOOTSTRAP_RG}`.

## 1. Set variables

```bash
# These come from the user inputs (see SKILL.md §Inputs).
export UAMI_NAME="<from infra/bootstrap output: deploy_uami_name>"
export BOOTSTRAP_RG="<from infra/bootstrap output: bootstrap_rg_name>"

export OLD_SUBJECT="repo:<old-owner>/<old-repo>:environment:production"
export NEW_SUBJECT="repo:<new-owner>/<new-repo>:environment:production"

# Discover the issuer + audience used by the existing creds (don't change these).
ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"
```

## 2. List existing federated credentials

```bash
az identity federated-credential list \
  --identity-name "${UAMI_NAME}" \
  --resource-group "${BOOTSTRAP_RG}" \
  --output table
```

Look for the row whose `Subject` matches `${OLD_SUBJECT}`. Note its
`Name` (you'll delete it in step 5). If there are credentials for
`pull_request` and `infra-apply` as well, you will rotate **each one
in turn** — repeat steps 3–5 per credential.

## 3. Add the NEW federated credential alongside the OLD

```bash
NEW_CRED_NAME="github-actions-prod-$(date +%Y%m%d)"

az identity federated-credential create \
  --name "${NEW_CRED_NAME}" \
  --identity-name "${UAMI_NAME}" \
  --resource-group "${BOOTSTRAP_RG}" \
  --issuer "${ISSUER}" \
  --subject "${NEW_SUBJECT}" \
  --audiences "${AUDIENCE}"
```

Verify both creds now exist on the UAMI:

```bash
az identity federated-credential list \
  --identity-name "${UAMI_NAME}" \
  --resource-group "${BOOTSTRAP_RG}" \
  --query '[].{name:name, subject:subject}' \
  --output table
```

You should see both `${OLD_SUBJECT}` and `${NEW_SUBJECT}` listed.

## 4. Validate the new credential by running the deploy workflow

```bash
# From the (renamed) repo's local checkout:
gh workflow run azure-deploy.yml --ref main

# Watch the run:
gh run watch
```

The OIDC token-exchange step (`Azure Login`) must succeed. If it fails
with `AADSTS70021`, double-check that `${NEW_SUBJECT}` exactly matches
the workflow's `${{ github.repository }}` + environment name (case
matters; `production` ≠ `Production`).

If it still fails, **do not delete the old credential** — debug first.

## 5. Remove the OLD federated credential

Once step 4 is green:

```bash
# Find the old credential's NAME (not subject) from step 2's output.
OLD_CRED_NAME="<the name of the credential whose subject = OLD_SUBJECT>"

az identity federated-credential delete \
  --name "${OLD_CRED_NAME}" \
  --identity-name "${UAMI_NAME}" \
  --resource-group "${BOOTSTRAP_RG}" \
  --yes
```

Re-list to confirm it's gone:

```bash
az identity federated-credential list \
  --identity-name "${UAMI_NAME}" \
  --resource-group "${BOOTSTRAP_RG}" \
  --query '[].subject' --output tsv
```

## 6. Repeat for other environments (if any)

If your repo also has federated credentials for `pull_request` and
`infra-apply` environments, repeat steps 3–5 with the matching
`OLD_SUBJECT` / `NEW_SUBJECT` values.

The full set of subject claims this template uses:

- `repo:<owner>/<repo>:environment:production`
- `repo:<owner>/<repo>:environment:infra-apply`
- `repo:<owner>/<repo>:pull_request`

## 7. Update the docs (if the rename is permanent)

Edit `docs/azure-oidc-setup.md` to reflect the new repo / environment
names in any worked examples.

If the rename is **temporary** (e.g. you transferred the repo to test
something and will transfer it back), skip this step and re-run the
playbook in reverse when the rename is undone.

## Rollback

If something goes wrong between steps 3 and 5 (the new credential is
not working and the old credential has been deleted prematurely):

1. Re-run step 3 with `OLD_SUBJECT` to recreate the original
   credential.
2. Trigger a `workflow_dispatch` on `azure-deploy.yml` to confirm
   service is restored.
3. Stop, file an issue with the failure mode, and start again from
   step 1 once root cause is understood.

## Done when

- Step 4's `azure-deploy.yml` run is green.
- Step 5 deleted the old credential.
- Step 6 has been repeated for every applicable environment.
- (If permanent rename) Step 7 updated the docs.
