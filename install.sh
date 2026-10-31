#!/usr/bin/env bash
# PenguTunnel bootstrap installer
# One-command run: download + extract + execute the real install.sh
set -euo pipefail

# ---------------- Config ----------------
VERSION="v5.1.6"
ZIP_NAME="PenguTunnel-${VERSION}-Offline.zip"
DOWNLOAD_URL="https://github.com/parhampahlevann/pangu/releases/download/${VERSION}/${ZIP_NAME}"
# Confirmed extracted folder name for this release: no "v" prefix, e.g.
# PenguTunnel-5.1.6-Offline (unlike the zip file name, which keeps the "v").
EXPECTED_DIR="PenguTunnel-${VERSION#v}-Offline"
WORK_DIR="/tmp/pangu-install-$$"
INSTALL_ARGS=(--repair-existing)

# ---------------- Helpers ----------------
need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "[!] This script must be run with sudo."
    echo "    Example: sudo bash <(curl -fsSL <url-of-this-file>)"
    exit 1
  fi
}

install_deps() {
  local missing=0
  command -v curl  >/dev/null 2>&1 || missing=1
  command -v unzip >/dev/null 2>&1 || missing=1
  if [ "$missing" -eq 1 ]; then
    echo "[*] Installing dependencies (curl, unzip)..."
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -y
      apt-get install -y curl unzip
    elif command -v yum >/dev/null 2>&1; then
      yum install -y curl unzip
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y curl unzip
    else
      echo "[!] No supported package manager found; install curl and unzip manually and rerun."
      exit 1
    fi
  fi
}

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# The folder name inside the zip doesn't necessarily match the zip's own
# file name (the zip carries the "v" prefix, e.g. PenguTunnel-v5.1.6-...,
# while the extracted folder is PenguTunnel-5.1.6-...-Offline), so detect
# it instead of hardcoding it — avoids breaking again on the next version
# or naming-scheme change.
detect_extract_dir() {
  local dirs count
  dirs=$(find . -mindepth 1 -maxdepth 1 -type d)
  count=$(printf '%s\n' "$dirs" | grep -c .)
  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$dirs"
  else
    echo ""
  fi
}

# ---------------- Main ----------------
main() {
  need_root
  install_deps

  mkdir -p "$WORK_DIR"
  cd "$WORK_DIR"

  echo "[*] Downloading ${ZIP_NAME} ..."
  curl -fsSL -o "$ZIP_NAME" "$DOWNLOAD_URL"

  echo "[*] Extracting archive..."
  unzip -oq "$ZIP_NAME"

  local extract_dir="$EXPECTED_DIR"
  if [ ! -d "$extract_dir" ]; then
    # Naming scheme changed from what we expected — fall back to detection
    # instead of failing outright.
    extract_dir="$(detect_extract_dir)"
  fi
  if [ -z "$extract_dir" ] || [ ! -d "$extract_dir" ]; then
    echo "[!] Could not find the extracted folder. Archive contents:"
    ls -la
    exit 1
  fi
  cd "$extract_dir"

  if [ ! -f "install.sh" ]; then
    echo "[!] install.sh not found inside the package."
    exit 1
  fi

  echo "[*] Running the PenguTunnel installer (${INSTALL_ARGS[*]})..."
  chmod +x install.sh
  bash install.sh "${INSTALL_ARGS[@]}" "$@"

  echo "[+] Installation complete."
}

main "$@"
