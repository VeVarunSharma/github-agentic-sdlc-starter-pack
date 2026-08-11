<!-- HAND-AUTHORED - safe rotation of all purpose-specific Azure OIDC trust. -->
---
name: oidc-rotation
description: "Rotate plan, apply, and deploy Azure federated credentials after GitHub repository trust changes"
applyTo: "infra/bootstrap/**"
---

# Skill: OIDC rotation

Use this skill after a repository rename/transfer, GitHub subject-format
migration, or recovery of one of the `infra-plan`, `infra-apply`, or
`production` environment credentials.

## Contract

- Rotate all three identities, not just production.
- Use the real bootstrap outputs `plan_client_id`, `apply_client_id`,
  `deploy_client_id`, `identity_names`, and `federation_subjects`.
- Preserve existing Azure resource names.
- Keep subjects exact; never add wildcard or pull-request federation.
- Default to immutable `OWNER@OWNER-ID/REPO@REPO-ID` subjects. Use the explicit
  `--legacy-subject` flag only for a verified older repository.
- Never replace the UAMIs merely because a repository display name changed.

Run the tested automation:

```bash
./scripts/setup-azure-oidc.sh --repo OWNER/REPO --rotate
```

See [`PLAYBOOK.md`](./PLAYBOOK.md) for validation, rollback, and legacy mode.
