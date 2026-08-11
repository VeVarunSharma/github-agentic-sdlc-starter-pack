<!-- HAND-AUTHORED -->

# OIDC rotation playbook

## 1. Inspect current trust

```bash
terraform -chdir=infra/bootstrap output identity_names
terraform -chdir=infra/bootstrap output federation_subjects
terraform -chdir=infra/bootstrap output plan_client_id
terraform -chdir=infra/bootstrap output apply_client_id
terraform -chdir=infra/bootstrap output deploy_client_id
```

Confirm the target repository's immutable IDs:

```bash
gh api repos/OWNER/REPO \
  --jq '{owner: .owner.login, owner_id: .owner.id, repo: .name, repo_id: .id}'
```

## 2. Rotate all three subjects

Immutable mode is the default:

```bash
./scripts/setup-azure-oidc.sh --repo OWNER/REPO --rotate
```

Only for a verified legacy repository:

```bash
./scripts/setup-azure-oidc.sh --repo OWNER/REPO --rotate --legacy-subject
```

`--rotate` reads the recorded `AZURE_OIDC_SUBJECT_MODE`, `identity_names`, `naming_inputs`,
`precomputed_acr_name`, `precomputed_web_app_name`, and state outputs before
applying, so a changed repository ID cannot rename Azure resources.
Federated credential names contain the subject hash and Terraform uses
`create_before_destroy`; each replacement is created before the previous exact
subject is removed.

## 3. Verify every identity

```bash
terraform -chdir=infra/bootstrap output federation_subjects
gh variable list --repo OWNER/REPO | grep -E \
  'AZURE_(PLAN|APPLY|DEPLOY)_CLIENT_ID|AZURE_OIDC_SUBJECT_MODE'
```

Exercise each environment:

1. Dispatch `infra-apply.yml`; confirm the `infra-plan` job authenticates.
2. Approve `infra-apply`; confirm checksum verification and the saved-plan
   apply authenticate with the apply identity.
3. Dispatch `azure-deploy.yml`; confirm production authentication with the
   deploy identity.

Do not remove/recreate identities as a workaround for a subject mismatch.

## Rollback

If immutable mode is not yet emitted by an older repository, immediately rerun:

```bash
./scripts/setup-azure-oidc.sh --repo OWNER/REPO --rotate --legacy-subject
```

Because names and identities are preserved, this changes only the three exact
federated credentials and the recorded subject-mode repository variable.
