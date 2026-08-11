#!/usr/bin/env bash
# scripts/install-apm.sh — install APM CLI v0.28.0 from the official GitHub release.
#
# Usage:
#   ./scripts/install-apm.sh
#
# Testability overrides (env vars, weaken nothing when unset):
#   APM_VERSION   — release tag to install   (default: 0.28.0)
#   APM_BASE_URL  — release base URL         (default: https://github.com/microsoft/apm/releases/download)
#   APM_DEST      — installation root dir    (default: $HOME/.local/apm)
#   APM_BIN_DIR   — directory for `apm` symlink (default: $HOME/.local/bin)
#
# The script:
#   1. Detects OS + arch and selects the correct release asset.
#   2. Downloads the tarball + its .sha256 sidecar from the GitHub release.
#   3. Verifies SHA-256 with shasum (macOS) or sha256sum (Linux).
#   4. Extracts the complete bundle (binary + _internal/) into APM_DEST/<version>/.
#   5. Creates a symlink APM_BIN_DIR/apm → the versioned binary.
#   6. Fails (exit 1) unless `apm --version` reports exactly APM_VERSION.
#
# Safe to re-run: re-download + re-verify + re-symlink on every call.
# Does NOT install system packages; requires: curl, shasum|sha256sum, tar.
#
# Asset naming convention (verified against v0.28.0 release):
#   apm-{OS}-{ARCH}.tar.gz          e.g. apm-darwin-arm64.tar.gz
#   apm-{OS}-{ARCH}.tar.gz.sha256   one-line BSD-style: "<hash>  <filename>"
#
# The extracted tarball top-level directory is apm-{OS}-{ARCH}/ and must be
# kept intact because the `apm` binary requires its `_internal/` sibling.

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
APM_VERSION="${APM_VERSION:-0.28.0}"
APM_BASE_URL="${APM_BASE_URL:-https://github.com/microsoft/apm/releases/download}"
APM_DEST="${APM_DEST:-$HOME/.local/apm}"
APM_BIN_DIR="${APM_BIN_DIR:-$HOME/.local/bin}"

# ── OS / arch detection ───────────────────────────────────────────────────────
_os=$(uname -s)
_arch=$(uname -m)

case "$_os" in
  Darwin) os="darwin" ;;
  Linux)  os="linux"  ;;
  *)      echo "[error] Unsupported OS: $_os" >&2; exit 1 ;;
esac

case "$_arch" in
  arm64|aarch64) arch="arm64"  ;;
  x86_64)        arch="x86_64" ;;
  *)             echo "[error] Unsupported architecture: $_arch" >&2; exit 1 ;;
esac

ASSET="apm-${os}-${arch}.tar.gz"
ASSET_SHA256="${ASSET}.sha256"
RELEASE_URL="${APM_BASE_URL}/v${APM_VERSION}"
BUNDLE_DIR="apm-${os}-${arch}"   # top-level dir inside the tarball

# ── Resolve paths to absolute ─────────────────────────────────────────────────
# Do this before any cd so relative paths supplied via env vars work correctly.
_abspath() { local p="$1"; mkdir -p "$p"; ( cd "$p" && pwd ); }

APM_DEST="$(_abspath "${APM_DEST}")"
APM_BIN_DIR="$(_abspath "${APM_BIN_DIR}")"
WORK_DIR="${APM_DEST}/downloads/v${APM_VERSION}"
INSTALL_DIR="${APM_DEST}/v${APM_VERSION}"
mkdir -p "$WORK_DIR"

echo "[apm-install] version=${APM_VERSION} os=${os} arch=${arch}"
echo "[apm-install] asset=${ASSET}"
echo "[apm-install] dest=${APM_DEST}"

# ── Download ──────────────────────────────────────────────────────────────────
echo "[apm-install] Downloading ${ASSET} ..."
curl -fSL "${RELEASE_URL}/${ASSET}"        -o "${WORK_DIR}/${ASSET}"
curl -fSL "${RELEASE_URL}/${ASSET_SHA256}" -o "${WORK_DIR}/${ASSET_SHA256}"

# ── SHA-256 verification ──────────────────────────────────────────────────────
# The .sha256 sidecar uses BSD-style format: "<hash>  <filename>".
# Both `shasum -a 256 -c` (macOS) and `sha256sum -c` (Linux/GNU) accept it
# when the working directory matches the filename in the sidecar.
echo "[apm-install] Verifying SHA-256 ..."
cd "$WORK_DIR"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c "$ASSET_SHA256"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 -c "$ASSET_SHA256"
else
  echo "[error] Neither sha256sum nor shasum found. Cannot verify integrity." >&2
  exit 1
fi

echo "[apm-install] SHA-256 OK"

# ── Extract ───────────────────────────────────────────────────────────────────
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"   # absolute

echo "[apm-install] Extracting to ${INSTALL_DIR} ..."
tar -xzf "$ASSET" -C "$INSTALL_DIR"

# The tarball extracts as: apm-{os}-{arch}/apm  and  apm-{os}-{arch}/_internal/
# Both must be preserved. The binary is at INSTALL_DIR/<BUNDLE_DIR>/apm.
BINARY="${INSTALL_DIR}/${BUNDLE_DIR}/apm"

if [[ ! -x "$BINARY" ]]; then
  echo "[error] Expected binary not found or not executable: ${BINARY}" >&2
  exit 1
fi

# ── Symlink ───────────────────────────────────────────────────────────────────
SYMLINK="${APM_BIN_DIR}/apm"
echo "[apm-install] Symlinking ${SYMLINK} -> ${BINARY} ..."
ln -sf "$BINARY" "$SYMLINK"

# ── Version check ─────────────────────────────────────────────────────────────
# Ensure the binary is runnable and reports the exact expected version.
REPORTED=$("$SYMLINK" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ "$REPORTED" != "$APM_VERSION" ]]; then
  echo "[error] Version mismatch: expected ${APM_VERSION}, got '${REPORTED}'" >&2
  exit 1
fi

echo "[apm-install] Success — apm ${APM_VERSION} installed at ${SYMLINK}"
echo "[apm-install] Add '${APM_BIN_DIR}' to PATH if not already present."
