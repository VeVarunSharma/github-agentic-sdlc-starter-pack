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

echo "doctor fixtures passed"
