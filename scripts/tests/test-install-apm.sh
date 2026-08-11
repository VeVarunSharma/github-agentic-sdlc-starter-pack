#!/usr/bin/env bash
# scripts/tests/test-install-apm.sh — self-tests for scripts/install-apm.sh.
#
# Uses isolated directories under .apm-install-test/selftest-install/ (never /tmp).
# Network-dependent tests inject a fake `curl` wrapper onto PATH.
#
# Usage:
#   bash scripts/tests/test-install-apm.sh
#
# Exit codes: 0 = all pass, 1 = at least one failure.
#
# Tests:
#   T1 — happy path: real download, SHA verify, extract, symlink, version check
#   T2 — bad SHA256: fake curl returns corrupt file + wrong hash → non-zero exit
#   T3 — wrong version: fake binary reports 9.9.9 → version-mismatch exit
#   T4 — unsupported OS: inject bad uname → "Unsupported OS" error
#   T5 — idempotence: re-run on existing install → exits 0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/install-apm.sh"
SCRATCH="${REPO_ROOT}/.apm-install-test/selftest-install"
mkdir -p "$SCRATCH"

pass=0; fail=0

_pass() { echo "  [PASS] $*"; pass=$((pass+1)); }
_fail() { echo "  [FAIL] $*"; fail=$((fail+1)); }

# Detect OS/arch (same logic as install script)
_OS=$(uname -s)
_ARCH=$(uname -m)
case "$_OS" in Darwin) _os="darwin";; Linux) _os="linux";; *) _os="unknown";; esac
case "$_ARCH" in arm64|aarch64) _arch="arm64";; x86_64) _arch="x86_64";; *) _arch="unknown";; esac
ASSET="apm-${_os}-${_arch}.tar.gz"
BUNDLE_DIR="apm-${_os}-${_arch}"

# ── Helper: build a minimal apm bundle ───────────────────────────────────────
# Creates a tarball + correct .sha256 at $1/ with a fake `apm` reporting ver $2.
_make_bundle() {
  local dir="$1" ver="$2"
  local bundle="${dir}/${BUNDLE_DIR}"
  rm -rf "$bundle"
  mkdir -p "${bundle}/_internal"
  printf '#!/bin/sh\necho "Agent Package Manager (APM) CLI version %s (fake)"\n' "$ver" \
    > "${bundle}/apm"
  chmod +x "${bundle}/apm"
  ( cd "$dir" && tar czf "${dir}/${ASSET}" "${BUNDLE_DIR}" )
  local hash
  hash=$(shasum -a 256 "${dir}/${ASSET}" | awk '{print $1}')
  printf '%s  %s\n' "$hash" "$ASSET" > "${dir}/${ASSET}.sha256"
}

# ── Helper: create a fake `curl` that serves fixture files ───────────────────
# Writes a /bin/sh script to $1/curl; maps URL basename → file in $2/.
_install_fake_curl() {
  local bin_dir="$1" fixture_dir="$2"
  mkdir -p "$bin_dir"
  # Write the fixture_dir assignment (needs expansion from outer shell),
  # then write the rest of the script using a quoted heredoc (no expansion).
  {
    printf '#!/bin/sh\n'
    printf 'fixture_dir="%s"\n' "$fixture_dir"
    cat <<'FAKECURL'
dest=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o)             dest="$2"; shift 2 ;;
    -fSL|-f|-S|-L)  shift ;;
    *)              url="$1"; shift ;;
  esac
done
filename=$(basename "$url")
src="${fixture_dir}/${filename}"
if [ ! -f "$src" ]; then
  echo "fake-curl: fixture not found: $src" >&2
  exit 22
fi
cp "$src" "$dest"
FAKECURL
  } > "${bin_dir}/curl"
  chmod +x "${bin_dir}/curl"
}

echo "=== install-apm.sh self-tests ==="
echo ""

# ── T1: Happy path (real network) ────────────────────────────────────────────
echo "T1: happy path (real download)"
DEST1="${SCRATCH}/t1/apm"
BIN1="${SCRATCH}/t1/bin"
rm -rf "${SCRATCH}/t1"
rc1=0
env APM_DEST="$DEST1" APM_BIN_DIR="$BIN1" bash "$SCRIPT" \
  >"${SCRATCH}/t1.log" 2>&1 || rc1=$?
if [[ "$rc1" -eq 0 ]] && [[ -x "${BIN1}/apm" ]]; then
  VER1=$("${BIN1}/apm" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [[ "$VER1" == "0.28.0" ]]; then
    _pass "T1: installed apm 0.28.0, symlink executable"
  else
    _fail "T1: binary reports version '$VER1', expected 0.28.0"
    cat "${SCRATCH}/t1.log"
  fi
else
  _fail "T1: install exited $rc1 or symlink missing"
  cat "${SCRATCH}/t1.log"
fi

# ── T2: Corrupt tarball → SHA mismatch → non-zero exit ───────────────────────
echo "T2: SHA256 mismatch → non-zero exit"
DEST2="${SCRATCH}/t2/apm"
BIN2="${SCRATCH}/t2/bin"
FIX2="${SCRATCH}/t2-fixture"
FBIN2="${SCRATCH}/t2-fakebin"
rm -rf "${SCRATCH}/t2" "$FIX2" "$FBIN2"
mkdir -p "$FIX2"
echo "this is not a valid tarball" > "${FIX2}/${ASSET}"
printf '%s  %s\n' \
  "0000000000000000000000000000000000000000000000000000000000000000" \
  "$ASSET" > "${FIX2}/${ASSET}.sha256"
_install_fake_curl "$FBIN2" "$FIX2"

rc2=0
env APM_DEST="$DEST2" APM_BIN_DIR="$BIN2" \
  PATH="${FBIN2}:${PATH}" bash "$SCRIPT" \
  >"${SCRATCH}/t2.log" 2>&1 || rc2=$?
if [[ "$rc2" -ne 0 ]]; then
  _pass "T2: corrupt tarball → exit $rc2 (non-zero as expected)"
else
  _fail "T2: expected non-zero exit for corrupt tarball, got 0"
  cat "${SCRATCH}/t2.log"
fi

# ── T3: Fake binary reports wrong version → version-mismatch exit ────────────
echo "T3: binary reports wrong version → version-mismatch exit"
DEST3="${SCRATCH}/t3/apm"
BIN3="${SCRATCH}/t3/bin"
FIX3="${SCRATCH}/t3-fixture"
FBIN3="${SCRATCH}/t3-fakebin"
rm -rf "${SCRATCH}/t3" "$FIX3" "$FBIN3"
mkdir -p "$FIX3"
_make_bundle "$FIX3" "9.9.9"
_install_fake_curl "$FBIN3" "$FIX3"

rc3=0
env APM_DEST="$DEST3" APM_BIN_DIR="$BIN3" \
  PATH="${FBIN3}:${PATH}" bash "$SCRIPT" \
  >"${SCRATCH}/t3.log" 2>&1 || rc3=$?
if [[ "$rc3" -ne 0 ]] && grep -q "Version mismatch" "${SCRATCH}/t3.log"; then
  _pass "T3: version mismatch detected, exited $rc3"
else
  _fail "T3: expected version-mismatch failure (got rc=$rc3)"
  cat "${SCRATCH}/t3.log"
fi

# ── T4: Unsupported OS → error ────────────────────────────────────────────────
echo "T4: unsupported OS → 'Unsupported OS' error"
WRAPPER4="${SCRATCH}/t4-wrapper.sh"
# Write the uname-override wrapper, then source the install script.
{
  cat <<'WRAP4HDR'
#!/bin/bash
uname() {
  if [[ "$1" == "-s" ]] || [[ $# -eq 0 ]]; then
    echo "SolarisX"
  else
    command uname "$@"
  fi
}
export -f uname
WRAP4HDR
  printf 'export APM_DEST="%s/t4/apm"\n' "$SCRATCH"
  printf 'export APM_BIN_DIR="%s/t4/bin"\n' "$SCRATCH"
  printf 'source "%s"\n' "$SCRIPT"
} > "$WRAPPER4"

rc4=0
bash "$WRAPPER4" >"${SCRATCH}/t4.log" 2>&1 || rc4=$?
if [[ "$rc4" -ne 0 ]] && grep -q "Unsupported OS" "${SCRATCH}/t4.log"; then
  _pass "T4: unsupported OS exited $rc4 with expected message"
else
  _fail "T4: expected 'Unsupported OS' error (got rc=$rc4)"
  cat "${SCRATCH}/t4.log"
fi

# ── T5: Idempotence — second run succeeds ────────────────────────────────────
echo "T5: idempotence (re-run on already-installed dir)"
if [[ -x "${BIN1}/apm" ]]; then
  rc5=0
  env APM_DEST="$DEST1" APM_BIN_DIR="$BIN1" bash "$SCRIPT" \
    >"${SCRATCH}/t5.log" 2>&1 || rc5=$?
  if [[ "$rc5" -eq 0 ]]; then
    _pass "T5: idempotent re-run succeeded"
  else
    _fail "T5: second run exited $rc5"
    cat "${SCRATCH}/t5.log"
  fi
else
  _fail "T5: skipped — T1 must pass first (no binary at ${BIN1}/apm)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${pass} passed, ${fail} failed"
[[ "$fail" -eq 0 ]]
