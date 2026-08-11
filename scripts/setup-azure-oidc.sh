#!/usr/bin/env bash
# Provision or rotate purpose-specific GitHub Actions OIDC identities.
set -euo pipefail

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  BLUE=$'\033[34m'
  GREEN=$'\033[32m'
  RED=$'\033[31m'
  RESET=$'\033[0m'
  YELLOW=$'\033[33m'
else
  BOLD=""
  BLUE=""
  GREEN=""
  RED=""
  RESET=""
  YELLOW=""
fi

info() { printf "%s>%s %s\n" "${BLUE}" "${RESET}" "$*"; }
ok() { printf "%sOK%s %s\n" "${GREEN}" "${RESET}" "$*"; }
warn() { printf "%sWARN%s %s\n" "${YELLOW}" "${RESET}" "$*" >&2; }
fail() { printf "%sERROR%s %s\n" "${RED}" "${RESET}" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
${BOLD}setup-azure-oidc.sh${RESET} - provision or rotate Azure OIDC trust

Creates separate plan, apply, and deploy UAMIs; exact environment federated
credentials; hardened tfstate storage; and every GitHub repository variable
required before the first infra/app apply.

Usage: $0 [OPTIONS]

Options:
  --repo OWNER/REPO       Target repository (default: current gh repository)
  --location REGION       Azure region (default: eastus)
  --region-short CODE     CAF region code (default: eus)
  --environment NAME      dev, test, staging, or prod (default: prod)
  --workload NAME         Lowercase alphanumeric workload segment
                          (default: sdlcstarter)
  --legacy-subject        Explicit compatibility mode for older repositories
                          whose OIDC subject is repo:OWNER/REPO:environment:ENV
  --rotate                Preserve resource names and the recorded subject mode;
                          overlap replacements before deleting old subjects
  --auto-approve          Skip confirmation and pass -auto-approve to Terraform
  -h, --help              Show this help

Immutable GitHub OIDC subjects are the default:
  repo:OWNER@OWNER-ID/REPO@REPO-ID:environment:ENV

Use --legacy-subject only after confirming the older repository still emits
the legacy subject. The script never guesses subject mode.
EOF
}

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

derive_unique_suffix() {
  local subscription_id="$1" owner_id="$2" repo_id="$3"
  printf '%s:%s:%s' "${subscription_id}" "${owner_id}" "${repo_id}" |
    sha256_hex |
    cut -c1-8
}

build_oidc_subject() {
  local mode="$1" owner="$2" repo="$3" owner_id="$4" repo_id="$5" environment="$6"
  case "${mode}" in
    immutable)
      printf 'repo:%s@%s/%s@%s:environment:%s\n' \
        "${owner}" "${owner_id}" "${repo}" "${repo_id}" "${environment}"
      ;;
    legacy)
      printf 'repo:%s/%s:environment:%s\n' "${owner}" "${repo}" "${environment}"
      ;;
    *)
      return 2
      ;;
  esac
}

derive_resource_names() {
  local workload="$1" environment="$2" region_short="$3" suffix="$4"
  local state_workload="${workload:0:8}"

  APP_RG_NAME="rg-${workload}-${environment}-${region_short}"
  STATE_RG_NAME="rg-${workload}-tfstate-${region_short}"
  PLAN_IDENTITY_NAME="id-${workload}-${environment}-plan"
  APPLY_IDENTITY_NAME="id-${workload}-${environment}-apply"
  DEPLOY_IDENTITY_NAME="id-${workload}-${environment}-deploy"
  STATE_STORAGE_ACCOUNT_NAME="st${state_workload}${environment:0:4}${suffix}"
  ACR_NAME="cr${workload}${environment}${suffix}"
  WEB_APP_NAME="app-${workload}-${environment}-${region_short}-${suffix}"
}

require_value() {
  local name="$1" value="$2"
  [[ -n "${value}" && "${value}" != "null" ]] || fail "Required value ${name} is empty"
}

terraform_output_value() {
  local output_json="$1" query="$2"
  jq -r "${query} // empty" <<<"${output_json}"
}

register_required_providers() {
  local namespace state
  local providers=(
    Microsoft.Authorization
    Microsoft.ContainerRegistry
    Microsoft.Insights
    Microsoft.ManagedIdentity
    Microsoft.OperationalInsights
    Microsoft.Resources
    Microsoft.Storage
    Microsoft.Web
  )

  info "Ensuring required Azure resource providers are registered"
  for namespace in "${providers[@]}"; do
    state="$(az provider show --namespace "${namespace}" --query registrationState -o tsv)"
    if [[ "${state}" != "Registered" ]]; then
      az provider register --namespace "${namespace}" --wait >/dev/null
    fi
  done
}

set_repo_variable() {
  local repo="$1" name="$2" value="$3"
  require_value "${name}" "${value}"
  gh variable set "${name}" --body "${value}" --repo "${repo}" >/dev/null
  printf "  %-34s %s\n" "${name}" "${value}"
}

main() {
  local repo=""
  local location="eastus"
  local region_short="eus"
  local environment="prod"
  local workload="sdlcstarter"
  local subject_mode="immutable"
  local subject_mode_explicit=false
  local auto_approve=false
  local rotate=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        [[ $# -ge 2 ]] || fail "--repo requires OWNER/REPO"
        repo="$2"
        shift 2
        ;;
      --location)
        [[ $# -ge 2 ]] || fail "--location requires a value"
        location="$2"
        shift 2
        ;;
      --region-short)
        [[ $# -ge 2 ]] || fail "--region-short requires a value"
        region_short="$2"
        shift 2
        ;;
      --environment)
        [[ $# -ge 2 ]] || fail "--environment requires a value"
        environment="$2"
        shift 2
        ;;
      --workload)
        [[ $# -ge 2 ]] || fail "--workload requires a value"
        workload="$2"
        shift 2
        ;;
      --legacy-subject)
        subject_mode="legacy"
        subject_mode_explicit=true
        shift
        ;;
      --rotate)
        rotate=true
        shift
        ;;
      --auto-approve)
        auto_approve=true
        shift
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        fail "Unknown argument: $1 (try --help)"
        ;;
    esac
  done

  [[ "${repo}" == */* && "${repo}" != */*/* ]] ||
    [[ -z "${repo}" ]] ||
    fail "--repo must use OWNER/REPO format"
  [[ "${location}" =~ ^[a-z][a-z0-9]{1,19}$ ]] ||
    fail "--location must be a lowercase Azure region name"
  [[ "${region_short}" =~ ^[a-z][a-z0-9]{1,7}$ ]] ||
    fail "--region-short must be 2-8 lowercase alphanumeric characters"
  [[ "${workload}" =~ ^[a-z][a-z0-9]{2,14}$ ]] ||
    fail "--workload must be 3-15 lowercase alphanumeric characters"
  case "${environment}" in
    dev | test | staging | prod) ;;
    *) fail "--environment must be dev, test, staging, or prod" ;;
  esac

  local repo_root
  repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "${repo_root}"

  local tool
  for tool in az gh jq; do
    command -v "${tool}" >/dev/null 2>&1 || fail "Required tool '${tool}' not found"
  done

  local tf_bin
  if command -v terraform >/dev/null 2>&1; then
    tf_bin="terraform"
  elif command -v tofu >/dev/null 2>&1; then
    tf_bin="tofu"
  else
    fail "Neither terraform nor tofu was found"
  fi

  az account show >/dev/null 2>&1 || fail "Run 'az login' first"
  gh auth status >/dev/null 2>&1 || fail "Run 'gh auth login' first"

  if [[ -z "${repo}" ]]; then
    repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
    require_value "repository" "${repo}"
  fi

  local repo_json owner repo_name owner_id repo_id
  repo_json="$(gh api "repos/${repo}")"
  owner="$(jq -r '.owner.login' <<<"${repo_json}")"
  repo_name="$(jq -r '.name' <<<"${repo_json}")"
  owner_id="$(jq -r '.owner.id | tostring' <<<"${repo_json}")"
  repo_id="$(jq -r '.id | tostring' <<<"${repo_json}")"
  [[ "${owner}/${repo_name}" == "${repo}" ]] ||
    fail "GitHub resolved ${repo} as ${owner}/${repo_name}; use the canonical name"
  [[ "${owner_id}" =~ ^[1-9][0-9]*$ && "${repo_id}" =~ ^[1-9][0-9]*$ ]] ||
    fail "GitHub did not return immutable numeric owner/repository IDs"

  if [[ "${rotate}" == "true" && "${subject_mode_explicit}" != "true" ]]; then
    local recorded_subject_mode
    recorded_subject_mode="$(
      gh variable get AZURE_OIDC_SUBJECT_MODE --repo "${repo}" 2>/dev/null || true
    )"
    case "${recorded_subject_mode}" in
      immutable | legacy)
        subject_mode="${recorded_subject_mode}"
        ;;
      "")
        warn "No recorded OIDC subject mode; using immutable. Pass --legacy-subject for a verified older repository."
        ;;
      *)
        fail "AZURE_OIDC_SUBJECT_MODE must be immutable or legacy"
        ;;
    esac
  fi

  local azure_context subscription_id subscription_name tenant_id
  azure_context="$(az account show --query '{id:id,name:name,tenantId:tenantId}' -o json)"
  subscription_id="$(jq -r .id <<<"${azure_context}")"
  subscription_name="$(jq -r .name <<<"${azure_context}")"
  tenant_id="$(jq -r .tenantId <<<"${azure_context}")"

  local suffix
  suffix="$(derive_unique_suffix "${subscription_id}" "${owner_id}" "${repo_id}")"
  derive_resource_names "${workload}" "${environment}" "${region_short}" "${suffix}"

  info "Repository: ${repo} (owner ID ${owner_id}, repo ID ${repo_id})"
  info "Subscription: ${subscription_name} (${subscription_id})"
  info "OIDC subject mode: ${subject_mode}"

  if [[ "${auto_approve}" != "true" ]]; then
    printf '\nThis will create/update three UAMIs, exact federated credentials,\n'
    printf 'scoped RBAC, hardened tfstate storage, GitHub environments, and repo variables.\n'
    read -r -p "Continue? [y/N] " response
    [[ "${response}" =~ ^[Yy]$ ]] || return 0
  fi

  register_required_providers

  "${tf_bin}" -chdir=infra/bootstrap init -input=false

  local existing_output=""
  if [[ "${rotate}" == "true" ]]; then
    existing_output="$("${tf_bin}" -chdir=infra/bootstrap output -json 2>/dev/null || true)"
    require_value "existing bootstrap outputs for --rotate" "${existing_output}"

    APP_RG_NAME="$(terraform_output_value "${existing_output}" '.app_resource_group_name.value')"
    STATE_RG_NAME="$(terraform_output_value "${existing_output}" '.tfstate_resource_group_name.value')"
    STATE_STORAGE_ACCOUNT_NAME="$(terraform_output_value "${existing_output}" '.tfstate_storage_account_name.value')"
    ACR_NAME="$(terraform_output_value "${existing_output}" '.precomputed_acr_name.value')"
    WEB_APP_NAME="$(terraform_output_value "${existing_output}" '.precomputed_web_app_name.value')"
    PLAN_IDENTITY_NAME="$(terraform_output_value "${existing_output}" '.identity_names.value.plan')"
    APPLY_IDENTITY_NAME="$(terraform_output_value "${existing_output}" '.identity_names.value.apply')"
    DEPLOY_IDENTITY_NAME="$(terraform_output_value "${existing_output}" '.identity_names.value.deploy')"
    workload="$(terraform_output_value "${existing_output}" '.naming_inputs.value.workload_name')"
    environment="$(terraform_output_value "${existing_output}" '.naming_inputs.value.environment')"
    region_short="$(terraform_output_value "${existing_output}" '.naming_inputs.value.region_short')"
    location="$(terraform_output_value "${existing_output}" '.naming_inputs.value.location')"

    require_value "existing state storage account" "${STATE_STORAGE_ACCOUNT_NAME}"
    info "Rotation mode: preserving all existing Azure resource names"
  fi

  local tf_var_args=(
    -var "acr_name=${ACR_NAME}"
    -var "app_resource_group_name=${APP_RG_NAME}"
    -var "apply_identity_name=${APPLY_IDENTITY_NAME}"
    -var "deploy_identity_name=${DEPLOY_IDENTITY_NAME}"
    -var "environment=${environment}"
    -var "github_owner=${owner}"
    -var "github_owner_id=${owner_id}"
    -var "github_repo=${repo_name}"
    -var "github_repo_id=${repo_id}"
    -var "location=${location}"
    -var "oidc_subject_mode=${subject_mode}"
    -var "plan_identity_name=${PLAN_IDENTITY_NAME}"
    -var "region_short=${region_short}"
    -var "state_resource_group_name=${STATE_RG_NAME}"
    -var "state_storage_account_name=${STATE_STORAGE_ACCOUNT_NAME}"
    -var "subscription_id=${subscription_id}"
    -var "web_app_name=${WEB_APP_NAME}"
    -var "workload_name=${workload}"
  )

  local apply_args=(-input=false)
  if [[ "${auto_approve}" == "true" ]]; then
    apply_args+=(-auto-approve)
  fi
  "${tf_bin}" -chdir=infra/bootstrap apply "${apply_args[@]}" "${tf_var_args[@]}"

  local tf_output
  tf_output="$("${tf_bin}" -chdir=infra/bootstrap output -json)"

  local plan_client_id apply_client_id deploy_client_id deploy_principal_id
  plan_client_id="$(terraform_output_value "${tf_output}" '.plan_client_id.value')"
  apply_client_id="$(terraform_output_value "${tf_output}" '.apply_client_id.value')"
  deploy_client_id="$(terraform_output_value "${tf_output}" '.deploy_client_id.value')"
  deploy_principal_id="$(terraform_output_value "${tf_output}" '.deploy_principal_id.value')"

  local env_name
  for env_name in infra-plan infra-apply production; do
    gh api --method PUT "repos/${repo}/environments/${env_name}" >/dev/null
  done

  info "Setting GitHub repository variables"
  set_repo_variable "${repo}" AZURE_PLAN_CLIENT_ID "${plan_client_id}"
  set_repo_variable "${repo}" AZURE_APPLY_CLIENT_ID "${apply_client_id}"
  set_repo_variable "${repo}" AZURE_DEPLOY_CLIENT_ID "${deploy_client_id}"
  set_repo_variable "${repo}" AZURE_DEPLOY_PRINCIPAL_ID "${deploy_principal_id}"
  set_repo_variable "${repo}" AZURE_TENANT_ID "${tenant_id}"
  set_repo_variable "${repo}" AZURE_SUBSCRIPTION_ID "${subscription_id}"
  set_repo_variable "${repo}" AZURE_RESOURCE_GROUP "${APP_RG_NAME}"
  set_repo_variable "${repo}" AZURE_TFSTATE_RG "${STATE_RG_NAME}"
  set_repo_variable "${repo}" AZURE_TFSTATE_STORAGE_ACCOUNT "${STATE_STORAGE_ACCOUNT_NAME}"
  set_repo_variable "${repo}" AZURE_TFSTATE_CONTAINER "tfstate"
  set_repo_variable "${repo}" AZURE_ACR_NAME "${ACR_NAME}"
  set_repo_variable "${repo}" AZURE_WEBAPP_NAME "${WEB_APP_NAME}"
  set_repo_variable "${repo}" AZURE_LOCATION "${location}"
  set_repo_variable "${repo}" AZURE_REGION_SHORT "${region_short}"
  set_repo_variable "${repo}" AZURE_ENVIRONMENT "${environment}"
  set_repo_variable "${repo}" AZURE_WORKLOAD_NAME "${workload}"
  set_repo_variable "${repo}" AZURE_OIDC_SUBJECT_MODE "${subject_mode}"

  ok "Azure bootstrap and GitHub repository variables are complete"
  cat <<EOF

Next steps:
  1. Configure required reviewers on the 'infra-apply' GitHub Environment.
     Keep 'infra-plan' ungated and configure 'production' for your deploy policy.
  2. Run the Infra Apply workflow. ACR and Web App names are already set:
       gh workflow run infra-apply.yml --repo ${repo}

The tfstate endpoint remains public for standard GitHub-hosted runners. For
regulated workloads, use fixed-egress/self-hosted runners plus storage network
rules or a private endpoint as documented in docs/azure-oidc-setup.md.
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
