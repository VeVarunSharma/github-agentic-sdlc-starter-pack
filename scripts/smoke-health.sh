#!/usr/bin/env bash
# Probe an HTTP health endpoint without converting transport failures into
# successful shell status.
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
  echo "Usage: $0 <health-url> [attempts] [delay-seconds]" >&2
  exit 2
fi

url="$1"
attempts="${2:-10}"
delay_seconds="${3:-6}"

if [[ ! "${attempts}" =~ ^[1-9][0-9]*$ || ! "${delay_seconds}" =~ ^[0-9]+$ ]]; then
  echo "attempts must be positive and delay-seconds must be non-negative" >&2
  exit 2
fi

case "${url}" in
  https://* | http://127.0.0.1:* | http://localhost:*) ;;
  *)
    echo "health URL must use HTTPS or a loopback HTTP address" >&2
    exit 2
    ;;
esac

response_file="$(mktemp "${TMPDIR:-/tmp}/health-response.XXXXXX")"
trap 'rm -f "${response_file}"' EXIT

for ((attempt = 1; attempt <= attempts; attempt += 1)); do
  set +e
  status_code="$(
    curl \
      --connect-timeout 10 \
      --max-time 20 \
      --output "${response_file}" \
      --silent \
      --show-error \
      --write-out '%{http_code}' \
      "${url}"
  )"
  curl_status=$?
  set -e

  if [[ "${curl_status}" -eq 0 && "${status_code}" == "200" ]] &&
    jq -e '.status == "ok" and (.uptime | type == "number")' \
      "${response_file}" >/dev/null; then
    printf 'Healthy response from %s\n' "${url}"
    return_status=0
    break
  fi

  printf 'Health attempt %d/%d failed (curl=%d, HTTP=%s)\n' \
    "${attempt}" "${attempts}" "${curl_status}" "${status_code:-none}" >&2
  return_status=1
  if [[ "${attempt}" -lt "${attempts}" ]]; then
    sleep "${delay_seconds}"
  fi
done

if [[ "${return_status}" -ne 0 ]]; then
  echo "Health endpoint did not become ready" >&2
  exit "${return_status}"
fi
