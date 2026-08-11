#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCTOR="${ROOT}/scripts/doctor.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/doctor-test.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

"${DOCTOR}" --help | grep -q -- '--strict'

if "${DOCTOR}" --not-an-option >/dev/null 2>&1; then
  echo "doctor accepted an invalid argument" >&2
  exit 1
fi

mkdir -p "${TMP}/placeholder"
printf '%s\n' '<owner>/<repo>' > "${TMP}/placeholder/README.md"
if DOCTOR_ROOT="${TMP}/placeholder" DOCTOR_REQUIRED_TOOLS="" \
  "${DOCTOR}" --strict >/dev/null 2>&1; then
  echo "strict doctor accepted unresolved placeholders" >&2
  exit 1
fi

mkdir -p "${TMP}/missing-tool"
if DOCTOR_ROOT="${TMP}/missing-tool" DOCTOR_REQUIRED_TOOLS="definitely-missing-tool" \
  "${DOCTOR}" --strict >/dev/null 2>&1; then
  echo "strict doctor accepted a missing required tool" >&2
  exit 1
fi

mkdir -p "${TMP}/cloud/bin" "${TMP}/cloud/repo"
git -C "${TMP}/cloud/repo" init --quiet
cat > "${TMP}/cloud/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "gh fixture" ;;
  auth) exit 0 ;;
  repo) echo "fixture/repo" ;;
  variable) printf '%s\n' ${DOCTOR_MOCK_VARIABLES:-} ;;
  api) exit 0 ;;
  *) exit 1 ;;
esac
EOF
cat > "${TMP}/cloud/bin/az" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "az fixture" ;;
  account) exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "${TMP}/cloud/bin/gh" "${TMP}/cloud/bin/az"

cloud_variables="AZURE_PLAN_CLIENT_ID AZURE_APPLY_CLIENT_ID AZURE_DEPLOY_CLIENT_ID AZURE_DEPLOY_PRINCIPAL_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP AZURE_TFSTATE_RG AZURE_TFSTATE_STORAGE_ACCOUNT AZURE_TFSTATE_CONTAINER AZURE_ACR_NAME AZURE_WEBAPP_NAME AZURE_LOCATION AZURE_REGION_SHORT AZURE_ENVIRONMENT AZURE_WORKLOAD_NAME AZURE_OIDC_SUBJECT_MODE"
PATH="${TMP}/cloud/bin:${PATH}" DOCTOR_ROOT="${TMP}/cloud/repo" \
  DOCTOR_REQUIRED_TOOLS="" DOCTOR_MOCK_VARIABLES="${cloud_variables}" \
  "${DOCTOR}" --strict --cloud >/dev/null

if PATH="${TMP}/cloud/bin:${PATH}" DOCTOR_ROOT="${TMP}/cloud/repo" \
  DOCTOR_REQUIRED_TOOLS="" \
  DOCTOR_MOCK_VARIABLES="${cloud_variables/AZURE_TFSTATE_CONTAINER/}" \
  "${DOCTOR}" --strict --cloud >/dev/null 2>&1; then
  echo "strict cloud doctor accepted a missing state variable" >&2
  exit 1
fi

echo "doctor fixtures passed"
