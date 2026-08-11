#!/usr/bin/env bash
# Offline regression tests for Azure OIDC trust, naming, and saved-plan safety.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

# shellcheck disable=SC1091
source scripts/setup-azure-oidc.sh

failures=0

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  if [[ "${actual}" != "${expected}" ]]; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' \
      "${message}" "${expected}" "${actual}" >&2
    failures=$((failures + 1))
  fi
}

assert_file_contains() {
  local file="$1" pattern="$2" message="$3"
  if ! grep -Eq -- "${pattern}" "${file}"; then
    printf 'FAIL: %s (%s)\n' "${message}" "${file}" >&2
    failures=$((failures + 1))
  fi
}

assert_file_not_contains() {
  local file="$1" pattern="$2" message="$3"
  if grep -Eq -- "${pattern}" "${file}"; then
    printf 'FAIL: %s (%s)\n' "${message}" "${file}" >&2
    failures=$((failures + 1))
  fi
}

suffix_one="$(derive_unique_suffix \
  00000000-0000-0000-0000-000000000001 12345 67890)"
suffix_two="$(derive_unique_suffix \
  00000000-0000-0000-0000-000000000001 12345 67890)"
suffix_other="$(derive_unique_suffix \
  00000000-0000-0000-0000-000000000002 12345 67890)"
assert_eq "${suffix_one}" "${suffix_two}" "stable IDs must produce a stable suffix"
if [[ "${suffix_one}" == "${suffix_other}" || ! "${suffix_one}" =~ ^[0-9a-f]{8}$ ]]; then
  printf 'FAIL: deterministic suffix must be eight lowercase hex characters and vary by stable IDs\n' >&2
  failures=$((failures + 1))
fi

derive_resource_names sdlcstarter prod eus "${suffix_one}"
assert_eq "rg-sdlcstarter-prod-eus" "${APP_RG_NAME}" "workload RG must follow CAF convention"
assert_eq "crsdlcstarterprod${suffix_one}" "${ACR_NAME}" "ACR name must be precomputed"
assert_eq "app-sdlcstarter-prod-eus-${suffix_one}" "${WEB_APP_NAME}" "Web App name must be precomputed"
[[ "${STATE_STORAGE_ACCOUNT_NAME}" =~ ^[a-z0-9]{3,24}$ ]] || {
  printf 'FAIL: state storage account name is invalid: %s\n' "${STATE_STORAGE_ACCOUNT_NAME}" >&2
  failures=$((failures + 1))
}

assert_eq \
  "repo:octo-org@12345/octo-repo@67890:environment:infra-plan" \
  "$(build_oidc_subject immutable octo-org octo-repo 12345 67890 infra-plan)" \
  "immutable subject must include stable owner and repo IDs"
assert_eq \
  "repo:octo-org/octo-repo:environment:production" \
  "$(build_oidc_subject legacy octo-org octo-repo 12345 67890 production)" \
  "legacy subject must require explicit compatibility mode"
if build_oidc_subject guessed octo-org octo-repo 12345 67890 production >/dev/null; then
  printf 'FAIL: unknown subject modes must be rejected\n' >&2
  failures=$((failures + 1))
fi

for environment_name in infra-plan infra-apply production; do
  assert_file_contains infra/bootstrap/main.tf \
    "environment:${environment_name}" \
    "bootstrap must create the ${environment_name} exact subject"
done
assert_file_not_contains infra/bootstrap/main.tf \
  "pull_request|pull-request" \
  "bootstrap must not create pull-request federation"

assert_file_contains infra/bootstrap/main.tf \
  'scope[[:space:]]*=[[:space:]]*azurerm_storage_container\.tfstate\[0\]\.id' \
  "plan/apply state access must use exact container scope"
assert_file_contains infra/bootstrap/main.tf \
  'condition_version[[:space:]]*=[[:space:]]*"2\.0"' \
  "apply RBAC delegation must use condition version 2.0"
assert_file_contains infra/bootstrap/providers.tf \
  'storage_use_azuread[[:space:]]*=[[:space:]]*true' \
  "AzureAD-only container creation must be enabled in the provider"
for state_setting in \
  'shared_access_key_enabled[[:space:]]*=[[:space:]]*false' \
  'default_to_oauth_authentication[[:space:]]*=[[:space:]]*true' \
  'versioning_enabled[[:space:]]*=[[:space:]]*true' \
  'container_delete_retention_policy' \
  'delete_after_days_since_creation[[:space:]]*=' \
  'lock_level[[:space:]]*=[[:space:]]*"CanNotDelete"'; do
  assert_file_contains infra/bootstrap/main.tf "${state_setting}" \
    "tfstate hardening setting must be present: ${state_setting}"
done
for role_id in \
  7f951dda-4ed3-4680-a7ca-43fe172d538d \
  8311e382-0749-4cb8-b61a-304f252e45ec \
  acdd72a7-3385-48ef-bd42-f606fba81ae7 \
  de139f84-1756-47ae-9be6-808fbbe84772 \
  f58310d9-a9f6-439a-9e8d-f62e7b41a168; do
  assert_file_contains infra/bootstrap/main.tf "${role_id}" \
    "bootstrap must use the required built-in role ID ${role_id}"
done
assert_file_contains infra/app/main.tf \
  'scope[[:space:]]*=[[:space:]]*azurerm_linux_web_app\.this\.id' \
  "Website Contributor must be scoped to the exact parent Web App"
assert_file_contains infra/app/main.tf \
  'scope[[:space:]]*=[[:space:]]*azurerm_container_registry\.this\.id' \
  "deploy ACR roles must be scoped to the exact registry"
assert_file_not_contains infra/app/providers.tf \
  'client_id|tenant_id|subscription_id|use_oidc' \
  "saved-plan provider configuration must not contain identity-specific settings"
assert_file_contains scripts/setup-azure-oidc.sh \
  'gh variable get AZURE_OIDC_SUBJECT_MODE' \
  "rotation must preserve the repository's explicitly recorded subject mode"

for validation_pattern in \
  'contains\(\["immutable", "legacy"\], var\.oidc_subject_mode\)' \
  'regex\("\^\[1-9\]\[0-9\]\*\$", var\.github_owner_id\)' \
  'regex\("\^\[1-9\]\[0-9\]\*\$", var\.github_repo_id\)' \
  'contains\(\["dev", "test", "staging", "prod"\], var\.environment\)' \
  'regex\("\^\[a-z\]\[a-z0-9\]\{1,7\}\$", var\.region_short\)'; do
  assert_file_contains infra/bootstrap/variables.tf "${validation_pattern}" \
    "bootstrap variable validation must be present: ${validation_pattern}"
done

required_repo_variables=(
  AZURE_PLAN_CLIENT_ID
  AZURE_APPLY_CLIENT_ID
  AZURE_DEPLOY_CLIENT_ID
  AZURE_DEPLOY_PRINCIPAL_ID
  AZURE_TENANT_ID
  AZURE_SUBSCRIPTION_ID
  AZURE_RESOURCE_GROUP
  AZURE_TFSTATE_RG
  AZURE_TFSTATE_STORAGE_ACCOUNT
  AZURE_TFSTATE_CONTAINER
  AZURE_ACR_NAME
  AZURE_WEBAPP_NAME
  AZURE_LOCATION
  AZURE_REGION_SHORT
  AZURE_ENVIRONMENT
  AZURE_WORKLOAD_NAME
  AZURE_OIDC_SUBJECT_MODE
)
for variable_name in "${required_repo_variables[@]}"; do
  assert_file_contains scripts/setup-azure-oidc.sh \
    "set_repo_variable .* ${variable_name} " \
    "setup must set ${variable_name} before the first app apply"
done

workflow=.github/workflows/infra-apply.yml
assert_file_contains "${workflow}" '^  plan:$' "workflow must have a plan job"
assert_file_contains "${workflow}" '^  apply:$' "workflow must have an apply job"
assert_file_contains "${workflow}" 'needs: plan' "apply must depend on plan"
assert_file_contains "${workflow}" 'environment: infra-plan' "plan must use infra-plan"
assert_file_contains "${workflow}" 'environment: infra-apply' "apply must use infra-apply"
assert_file_contains "${workflow}" 'retention-days: 5' "binary plan retention must be short"
assert_file_contains "${workflow}" 'sha256sum tfplan' "both jobs must calculate plan SHA-256"
assert_file_contains "${workflow}" 'EXPECTED_SHA256' "apply must independently verify checksum"
assert_file_contains "${workflow}" \
  'terraform apply -input=false -auto-approve -lock-timeout=5m tfplan' \
  "apply must consume only the saved plan"
assert_file_not_contains "${workflow}" \
  'auto_approve:|terraform output -json|terraform show -no-color tfplan' \
  "workflow must not expose sensitive plans/outputs or offer an approval bypass"

help_output="$(scripts/setup-azure-oidc.sh --help)"
[[ "${help_output}" == *"--rotate"* &&
   "${help_output}" == *"--legacy-subject"* &&
   "${help_output}" == *"OWNER@OWNER-ID/REPO@REPO-ID"* ]] || {
  printf 'FAIL: setup help must document rotation and both subject modes\n' >&2
  failures=$((failures + 1))
}

if scripts/setup-azure-oidc.sh --definitely-invalid >/dev/null 2>&1; then
  printf 'FAIL: setup must reject unknown arguments\n' >&2
  failures=$((failures + 1))
fi
if scripts/setup-azure-oidc.sh --repo >/dev/null 2>&1; then
  printf 'FAIL: setup must reject a missing --repo value\n' >&2
  failures=$((failures + 1))
fi
for invalid_args in \
  "--environment qa" \
  "--region-short EUS" \
  "--workload bad-name"; do
  # Intentional word splitting turns each fixture into CLI arguments.
  # shellcheck disable=SC2086
  if scripts/setup-azure-oidc.sh ${invalid_args} >/dev/null 2>&1; then
    printf 'FAIL: setup must reject invalid arguments: %s\n' "${invalid_args}" >&2
    failures=$((failures + 1))
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  printf '%s Azure OIDC test(s) failed\n' "${failures}" >&2
  exit 1
fi

echo "Azure OIDC naming, subjects, scopes, variables, and workflow safety are valid."
