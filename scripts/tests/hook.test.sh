#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${ROOT}/.github/hooks/scripts/validate-agent-edits.sh"
PS_HOOK="${ROOT}/.github/hooks/scripts/validate-agent-edits.ps1"
FIXTURES="${ROOT}/tools/harness/test/fixtures/hooks"

cd "${ROOT}"

output="$("${HOOK}" < "${FIXTURES}/irrelevant.json")"
printf '%s\n' "${output}" | jq -e 'type == "object" and length == 0' >/dev/null

output="$("${HOOK}" < "${FIXTURES}/relevant.json")"
printf '%s\n' "${output}" | jq -e 'type == "object" and length == 0' >/dev/null

invalid_root="$(mktemp -d "${TMPDIR:-/tmp}/hook-invalid.XXXXXX")"
trap 'rm -rf "${invalid_root}"' EXIT

output="$(HARNESS_ROOT="${invalid_root}" "${HOOK}" <<EOF
{"sessionId":"fixture","timestamp":0,"cwd":"${ROOT}","toolName":"apply_patch","toolArgs":{"path":"${ROOT}/docs/README.md"},"toolResult":{"resultType":"success","textResultForLlm":"ok"}}
EOF
)"
printf '%s\n' "${output}" |
  jq -e '.additionalContext | contains("Deterministic agent harness validation failed")' >/dev/null

output="$(HARNESS_ROOT="${invalid_root}" "${HOOK}" <<EOF
{"sessionId":"fixture","timestamp":0,"cwd":"${ROOT}","transcriptPath":"/tmp/transcript.jsonl","stopReason":"end_turn","stop_hook_active":false}
EOF
)"
printf '%s\n' "${output}" |
  jq -e '.decision == "block" and (.reason | contains("Deterministic agent harness validation failed"))' >/dev/null

set +e
output="$("${HOOK}" < "${FIXTURES}/malformed.json")"
status=$?
set -e
[[ "${status}" -ne 0 ]]
printf '%s\n' "${output}" | jq -e '.additionalContext | contains("Invalid lifecycle hook input")' >/dev/null

grep -Eq '^node tools/harness/src/hook\.mjs$' "${PS_HOOK}"
if command -v pwsh >/dev/null 2>&1; then
  output="$(pwsh -NoProfile -File "${PS_HOOK}" < "${FIXTURES}/irrelevant.json")"
  printf '%s\n' "${output}" | jq -e 'type == "object" and length == 0' >/dev/null
fi

echo "lifecycle hook fixtures passed"
