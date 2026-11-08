#!/usr/bin/env bash
# PenguTunnel one-click installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/parhampahlevann/pangu/main/install.sh)

set -euo pipefail

VERSION="5.4.1"
ZIP_NAME="PenguTunnel-${VERSION}-Offline-Fix1-linux-amd64.zip"
DIR_NAME="PenguTunnel-${VERSION}-Offline-Fix1-linux-amd64"
URL="https://github.com/parhampahlevann/pangu/releases/download/v5.1.6/${ZIP_NAME}"

# --- root check ---
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  else
    echo "[!] Please run as root." >&2
    exit 1
  fi
fi

# --- architecture check ---
ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
  echo "[!] This package is linux-amd64 only. Detected: $ARCH" >&2
  exit 1
fi

# --- dependencies ---
need_pkg=()
command -v unzip >/dev/null 2>&1 || need_pkg+=(unzip)
command -v curl  >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || need_pkg+=(curl)

if ((${#need_pkg[@]})); then
  echo "[*] Installing dependencies: ${need_pkg[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y "${need_pkg[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "${need_pkg[@]}"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "${need_pkg[@]}"
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache "${need_pkg[@]}"
  else
    echo "[!] Unknown package manager. Install manually: ${need_pkg[*]}" >&2
    exit 1
  fi
fi

# --- download ---
WORKDIR="$(mktemp -d /tmp/pengutunnel.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "[*] Downloading ${ZIP_NAME} ..."
if command -v curl >/dev/null 2>&1; then
  curl -fL --retry 3 --retry-delay 2 -o "$ZIP_NAME" "$URL"
else
  wget -q --tries=3 -O "$ZIP_NAME" "$URL"
fi

# --- extract ---
echo "[*] Extracting ..."
unzip -oq "$ZIP_NAME"

if [[ ! -d "$DIR_NAME" ]]; then
  echo "[!] Expected folder '$DIR_NAME' not found after extraction." >&2
  exit 1
fi
cd "$DIR_NAME"

if [[ ! -f install.sh ]]; then
  echo "[!] install.sh not found inside the package." >&2
  exit 1
fi

# --- install + open menu ---
# NOTE: --repair-existing is only for fixing a tampered/mismatched core binary;
# it exits right after and never opens the menu. A plain run (no args) installs
# the core if needed (ensure_core) and then calls menu() directly — that's the
# correct one-click path.
echo "[*] Running installer ..."
exec bash install.sh
