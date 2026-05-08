#!/usr/bin/env bash
# scripts/setup-azure-oidc.sh
# ─────────────────────────────────────────────────────────────────────────────
# One-time Azure OIDC bootstrap. Runs locally with 'az login' + 'gh auth
# login'. Creates the deploy managed identity, federated credentials, the
# app resource group, and the tfstate backend in Azure, then pushes the
# resulting identifiers to GitHub repository VARIABLES (not secrets — these
# IDs are not credentials).
#
# Idempotent: re-running is safe; Terraform only applies diffs.
#
# Usage:
#   ./scripts/setup-azure-oidc.sh [--repo OWNER/REPO] [--auto-approve] [--help]
#
# Source contract: docs/spike-d-azure-oidc.md §8 (adapted to actual
# infra/bootstrap/outputs.tf names).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info()  { printf "%s▶%s %s\n"  "${BLUE}"   "${RESET}" "$*"; }
ok()    { printf "%s✓%s %s\n"  "${GREEN}"  "${RESET}" "$*"; }
warn()  { printf "%s⚠%s %s\n"  "${YELLOW}" "${RESET}" "$*" >&2; }
fail()  { printf "%s✗%s %s\n"  "${RED}"    "${RESET}" "$*" >&2; exit 1; }

# ── Args ─────────────────────────────────────────────────────────────────────
REPO=""
AUTO_APPROVE=false

usage() {
  cat <<EOF
${BOLD}setup-azure-oidc.sh${RESET} — provision Azure deploy identity + GitHub vars

Creates the Azure UAMI + federated credentials + resource group + tfstate
backend, then sets the repo variables that the CI/CD workflows read:
  AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID,
  AZURE_RESOURCE_GROUP, AZURE_TFSTATE_RG,
  AZURE_TFSTATE_STORAGE_ACCOUNT, AZURE_TFSTATE_CONTAINER

Usage: $0 [OPTIONS]

Options:
  --repo OWNER/REPO    Target repo (defaults to 'gh repo view' result)
  --auto-approve       Skip the interactive 'continue?' prompt and the
                       Terraform plan-then-confirm step
  -h, --help           Show this help

Prerequisites:
  - az login (Azure CLI)
  - gh auth login (GitHub CLI, scope 'repo')
  - terraform (or tofu) on PATH
  - jq

After this script succeeds, two manual steps remain:
  1. Create GitHub environments 'production' and 'infra-apply'
     (Settings → Environments). Required for the federated credentials.
  2. Run the 'infra-apply' workflow once to create the App Service + ACR,
     then set AZURE_ACR_NAME and AZURE_WEBAPP_NAME from its outputs.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)         REPO="${2:-}"; shift 2 ;;
    --auto-approve) AUTO_APPROVE=true; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              fail "Unknown argument: $1 (try --help)" ;;
  esac
done

# ── Locate repo root ─────────────────────────────────────────────────────────
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# ── Preflight ────────────────────────────────────────────────────────────────
info "Checking prerequisites"
command -v az  >/dev/null 2>&1 || fail "Azure CLI (az) not found. Install: https://aka.ms/installazurecli"
command -v gh  >/dev/null 2>&1 || fail "GitHub CLI (gh) not found. Install: https://cli.github.com/"
command -v jq  >/dev/null 2>&1 || fail "jq not found (brew install jq / apt install jq)"

if   command -v terraform >/dev/null 2>&1; then TF_BIN="terraform"
elif command -v tofu      >/dev/null 2>&1; then TF_BIN="tofu"
else fail "Neither terraform nor tofu found. Install: https://terraform.io/downloads"
fi
ok "Using Terraform binary: ${TF_BIN}"

az account show >/dev/null 2>&1 || fail "Not logged in to Azure. Run: az login"
gh auth status  >/dev/null 2>&1 || fail "Not logged in to GitHub CLI. Run: gh auth login"
ok "az + gh logins OK"

# ── Resolve target repo ──────────────────────────────────────────────────────
if [[ -z "${REPO}" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  [[ -n "${REPO}" ]] || fail "Could not detect target repo. Pass --repo OWNER/REPO."
fi
info "Target repo: ${BOLD}${REPO}${RESET}"

# Detect Azure context
AZ_CTX="$(az account show --query '{sub:id, subName:name, tenant:tenantId}' -o json)"
SUB_ID="$(echo "${AZ_CTX}"  | jq -r .sub)"
SUB_NAME="$(echo "${AZ_CTX}" | jq -r .subName)"
TEN_ID="$(echo "${AZ_CTX}"  | jq -r .tenant)"
info "Azure subscription: ${BOLD}${SUB_NAME}${RESET} (${SUB_ID})"
info "Azure tenant: ${TEN_ID}"

# ── Confirm ──────────────────────────────────────────────────────────────────
if [[ "${AUTO_APPROVE}" != "true" ]]; then
  echo ""
  echo "${YELLOW}This will:${RESET}"
  echo "  1. Run '${TF_BIN} apply' in infra/bootstrap/ — creates Azure resources"
  echo "     (UAMI, federated creds, RG, tfstate Storage Account)"
  echo "  2. Set GitHub repo variables on ${REPO}"
  echo ""
  read -r -p "Continue? [y/N] " response
  [[ "${response}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# ── Terraform apply ──────────────────────────────────────────────────────────
info "Initializing Terraform in infra/bootstrap/"
"${TF_BIN}" -chdir=infra/bootstrap init -input=false

# Derive a globally-unique tfstate storage account name. Storage accounts
# must be 3-24 lowercase alphanumeric with no hyphens. We deterministically
# hash the OWNER/REPO so re-running on the same repo produces the same name
# (idempotent), and prefix with `tfst` so it's recognisable.
SA_HASH="$(printf '%s' "${REPO}" | shasum -a 256 | cut -c1-16 | tr -d '\n')"
STATE_SA="tfst${SA_HASH}"

# Build the var args. tenant_id is NOT passed — bootstrap doesn't declare
# it as a variable (the deploy UAMI's tenant_id is read from the resource
# itself and exposed via outputs.tenant_id which we read back below).
TF_VAR_ARGS=(
  -var "github_owner=${REPO%%/*}"
  -var "github_repo=${REPO##*/}"
  -var "subscription_id=${SUB_ID}"
  -var "state_storage_account_name=${STATE_SA}"
)

info "Applying Terraform in infra/bootstrap/"
if [[ "${AUTO_APPROVE}" == "true" ]]; then
  "${TF_BIN}" -chdir=infra/bootstrap apply -auto-approve -input=false "${TF_VAR_ARGS[@]}"
else
  "${TF_BIN}" -chdir=infra/bootstrap apply -input=false "${TF_VAR_ARGS[@]}"
fi
ok "Terraform apply complete"

# unused — kept here for reference; the script no longer passes tenant_id
# because bootstrap doesn't declare it as a variable (the UAMI's tenant is
# read from the resource itself and exposed via outputs.tenant_id).
: "${TEN_ID}"

# ── Read outputs ─────────────────────────────────────────────────────────────
info "Reading Terraform outputs"
TF_OUT="$("${TF_BIN}" -chdir=infra/bootstrap output -json)"

CLIENT_ID="$(echo "${TF_OUT}"        | jq -r '.client_id.value')"
TENANT_ID="$(echo "${TF_OUT}"        | jq -r '.tenant_id.value')"
SUBSCRIPTION_ID="$(echo "${TF_OUT}"  | jq -r '.subscription_id.value')"
APP_RG="$(echo "${TF_OUT}"           | jq -r '.app_resource_group_name.value')"
TFSTATE_RG="$(echo "${TF_OUT}"       | jq -r '.tfstate_resource_group_name.value // empty')"
TFSTATE_SA="$(echo "${TF_OUT}"       | jq -r '.tfstate_storage_account_name.value // empty')"
TFSTATE_CONTAINER="$(echo "${TF_OUT}" | jq -r '.tfstate_container_name.value // empty')"

# ── Set GitHub variables ─────────────────────────────────────────────────────
info "Setting GitHub repository variables on ${REPO}"

set_var() {
  local name="$1" value="$2"
  if [[ -z "${value}" || "${value}" == "null" ]]; then
    warn "Skipping ${name} (empty Terraform output)"
    return 0
  fi
  gh variable set "${name}" --body "${value}" --repo "${REPO}" >/dev/null
  printf "  %s%-32s%s = %s\n" "${BOLD}" "${name}" "${RESET}" "${value}"
}

set_var AZURE_CLIENT_ID              "${CLIENT_ID}"
set_var AZURE_TENANT_ID              "${TENANT_ID}"
set_var AZURE_SUBSCRIPTION_ID        "${SUBSCRIPTION_ID}"
set_var AZURE_RESOURCE_GROUP         "${APP_RG}"
set_var AZURE_TFSTATE_RG             "${TFSTATE_RG}"
set_var AZURE_TFSTATE_STORAGE_ACCOUNT "${TFSTATE_SA}"
set_var AZURE_TFSTATE_CONTAINER      "${TFSTATE_CONTAINER}"

ok "GitHub variables set"

# ── Next steps ───────────────────────────────────────────────────────────────
cat <<EOF

${BOLD}═══ Bootstrap complete ═══${RESET}

${BOLD}Next steps${RESET}
  1. Create GitHub environments 'production' and 'infra-apply':
       https://github.com/${REPO}/settings/environments
     Federated credentials are pinned to these environment names.

  2. Run the 'infra-apply' workflow once to provision App Service + ACR:
       gh workflow run infra-apply.yml --repo ${REPO}
     Then set the two remaining repo variables from its outputs:
       gh variable set AZURE_ACR_NAME      --body <acr-name>      --repo ${REPO}
       gh variable set AZURE_WEBAPP_NAME   --body <webapp-name>   --repo ${REPO}

  3. Push to main (or merge a PR) — 'azure-deploy.yml' will deploy.

  4. To rotate / re-bind federated credentials (e.g. after renaming the repo
     or an environment), re-run this script.

Verify federated credentials in the Azure portal:
  https://portal.azure.com → Managed Identities → Federated credentials
EOF
