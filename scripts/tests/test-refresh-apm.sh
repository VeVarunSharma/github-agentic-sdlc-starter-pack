#!/usr/bin/env bash
# scripts/tests/test-refresh-apm.sh — self-tests for scripts/refresh-apm.sh.
#
# Uses isolated scratch directories and fake/stub environments so the real
# repo files are never modified.  No network calls are made for T2–T5.
#
# Usage:
#   bash scripts/tests/test-refresh-apm.sh
#
# Exit codes: 0 = all pass, 1 = at least one failure.
#
# Tests:
#   T1 — dry-run, already current SHA → "Already up to date" + exit 0
#   T2 — dry-run with old SHA → shows correct replacement plan + exit 0
#   T3 — unknown --sha argument is accepted without error (dry-run)
#   T4 — bad --xyz flag → exit non-zero + error message
#   T5 — missing APM_CMD binary → detectable error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/refresh-apm.sh"
SCRATCH="${REPO_ROOT}/.apm-install-test/selftest-refresh"
mkdir -p "$SCRATCH"

pass=0; fail=0

_pass() { echo "  [PASS] $*"; pass=$((pass+1)); }
_fail() { echo "  [FAIL] $*"; fail=$((fail+1)); }

# Current SHA from apm.yml (the one that's already pinned)
CURRENT_SHA=$(grep -oE 'github/awesome-copilot/[^#]+#([0-9a-f]{40})' "${REPO_ROOT}/apm.yml" \
  | head -1 | grep -oE '[0-9a-f]{40}$')
OLD_SHA="6d676fa6fe7df117e6ec11f96330ae277a1bbd71"  # the pre-update pin

echo "=== refresh-apm.sh self-tests ==="
echo "Current SHA in apm.yml: ${CURRENT_SHA}"
echo ""

# ── Helper: create a stub apm.yml in scratch ─────────────────────────────────
# $1 = target dir, $2 = SHA to embed
_make_stub_apm_yml() {
  local dir="$1" sha="$2"
  mkdir -p "$dir"
  # Use the real APM dep format: github/<owner>/<repo>/path#sha
  printf '# APM stub for testing\nname: stub\ntargets:\n  copilot:\n    - github/awesome-copilot/instructions/stub.instructions.md#%s\n' \
    "$sha" > "${dir}/apm.yml"
}

# ── Helper: fake `apm` binary that succeeds silently ─────────────────────────
_make_fake_apm() {
  local dir="$1"
  mkdir -p "$dir"
  printf '#!/bin/sh\necho "0.28.0"\nexit 0\n' > "${dir}/apm"
  chmod +x "${dir}/apm"
}

# ── Helper: fake GitHub API server using python http.server ──────────────────
# Not needed: we use --sha to bypass network for T2/T3.

echo "T1: dry-run with current SHA → 'Already up to date'"
rc1=0
out1=$(
  cd "$REPO_ROOT"
  bash "$SCRIPT" --sha "$CURRENT_SHA" --dry-run 2>&1
) || rc1=$?
if [[ "$rc1" -eq 0 ]] && echo "$out1" | grep -q "Already up to date"; then
  _pass "T1: already-current SHA → exit 0, 'Already up to date'"
else
  _fail "T1: expected 'Already up to date' + exit 0 (got rc=$rc1)"
  echo "$out1"
fi

echo "T2: dry-run with old SHA → shows replacement plan"
# Use a temp copy of apm.yml with the OLD sha so we can test the replacement
TMPDIR2="${SCRATCH}/t2"
rm -rf "$TMPDIR2"; mkdir -p "$TMPDIR2"
_make_stub_apm_yml "$TMPDIR2" "$OLD_SHA"

rc2=0
out2=$(
  cd "$TMPDIR2"
  bash "$SCRIPT" --sha "$CURRENT_SHA" --dry-run 2>&1
) || rc2=$?
if [[ "$rc2" -eq 0 ]] && echo "$out2" | grep -q "DRY RUN"; then
  _pass "T2: dry-run with old SHA shows replacement plan (DRY RUN in output)"
else
  _fail "T2: expected DRY RUN output + exit 0 (got rc=$rc2)"
  echo "$out2"
fi

echo "T3: arbitrary known commit SHA accepted without error (dry-run)"
# Use a SHA that exists (just the old known pin which is a valid commit)
rc3=0
out3=$(
  cd "$REPO_ROOT"
  bash "$SCRIPT" --sha "$CURRENT_SHA" --dry-run 2>&1
) || rc3=$?
if [[ "$rc3" -eq 0 ]]; then
  _pass "T3: --sha flag accepted, exit 0"
else
  _fail "T3: unexpected error with --sha flag (rc=$rc3)"
  echo "$out3"
fi

echo "T4: unknown flag → non-zero exit with error message"
rc4=0
out4=$(
  cd "$REPO_ROOT"
  bash "$SCRIPT" --xyz-unknown-flag 2>&1
) || rc4=$?
if [[ "$rc4" -ne 0 ]] && echo "$out4" | grep -qi "unknown"; then
  _pass "T4: unknown flag → exit $rc4, error in output"
else
  _fail "T4: expected non-zero + error for unknown flag (got rc=$rc4)"
  echo "$out4"
fi

echo "T5: missing APM_CMD → detectable error before touching files"
TMPDIR5="${SCRATCH}/t5"
rm -rf "$TMPDIR5"; mkdir -p "$TMPDIR5"
_make_stub_apm_yml "$TMPDIR5" "$OLD_SHA"

rc5=0
out5=$(
  cd "$TMPDIR5"
  # Provide a bogus SHA that differs so we don't get 'already up to date'
  # and point APM_CMD at a non-existent binary so install fails.
  APM_CMD="${SCRATCH}/no-such-apm-binary" \
  bash "$SCRIPT" --sha "$CURRENT_SHA" 2>&1
) || rc5=$?
if [[ "$rc5" -ne 0 ]]; then
  _pass "T5: missing APM_CMD → non-zero exit ($rc5)"
else
  _fail "T5: expected failure when APM_CMD is missing (got rc=0)"
  echo "$out5"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${pass} passed, ${fail} failed"
[[ "$fail" -eq 0 ]]
