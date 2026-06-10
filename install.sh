#!/usr/bin/env bash
# =============================================================================
# strreplace installer
# Usage: curl -fsSL https://raw.githubusercontent.com/doggy8088/strreplace/main/install.sh | bash
# =============================================================================
set -euo pipefail

REPO="doggy8088/strreplace"
BIN_NAME="strreplace"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '\033[1;34m[strreplace]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[strreplace]\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31m[strreplace]\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" &>/dev/null || err "Required tool not found: $1"; }

need curl
need chmod

# ---------------------------------------------------------------------------
# Resolve latest release tag
# ---------------------------------------------------------------------------
info "Fetching latest release from github.com/${REPO} …"

API_URL="https://api.github.com/repos/${REPO}/releases/latest"
TAG=$(curl -fsSL "$API_URL" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

[ -n "$TAG" ] || err "Could not determine the latest release tag."

info "Latest release: ${TAG}"

# ---------------------------------------------------------------------------
# Download strreplace.sh
# ---------------------------------------------------------------------------
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/strreplace.sh"
TMP_FILE="$(mktemp /tmp/strreplace.XXXXXX)"
trap 'rm -f "$TMP_FILE"' EXIT

info "Downloading strreplace.sh from ${DOWNLOAD_URL} …"
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_FILE" || err "Download failed."

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
INSTALL_PATH="${INSTALL_DIR}/${BIN_NAME}"

if [ ! -w "$INSTALL_DIR" ]; then
  info "Installing to ${INSTALL_PATH} (requires sudo) …"
  sudo install -m 0755 "$TMP_FILE" "$INSTALL_PATH"
else
  info "Installing to ${INSTALL_PATH} …"
  install -m 0755 "$TMP_FILE" "$INSTALL_PATH"
fi

ok "Installed ${BIN_NAME} ${TAG} → ${INSTALL_PATH}"
ok "Run 'strreplace --help' to get started."
