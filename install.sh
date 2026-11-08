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

# --- install ---
MARKER="/tmp/.pengutunnel_marker_$$"
touch "$MARKER"

echo "[*] Running installer (--repair-existing) ..."
bash install.sh --repair-existing

echo "[+] PenguTunnel ${VERSION} installed successfully."

# --- auto-detect the installed command/menu ---
# 1) paths the package's own install.sh writes to (cp/install/ln -sf targets)
mapfile -t REF_PATHS < <(
  grep -oE '(/usr/(local/)?s?bin|/opt/[A-Za-z0-9._-]+)/[A-Za-z0-9._-]+' install.sh 2>/dev/null | sort -u
)

# 2) binaries that actually appeared on disk during this install
mapfile -t NEW_BINS < <(
  find /usr/local/bin /usr/bin /opt -maxdepth 2 -type f -newer "$MARKER" -perm -u+x 2>/dev/null
)

FOUND=""
for c in "${NEW_BINS[@]}" "${REF_PATHS[@]}"; do
  [[ -n "$c" && -x "$c" ]] && { FOUND="$c"; break; }
done

rm -f "$MARKER"

if [[ -n "$FOUND" ]]; then
  echo "[*] Launching menu: $FOUND"
  echo
  exec "$FOUND"
fi

# --- fallback: nothing auto-launchable found, show diagnostics instead of failing silently ---
echo
echo "[!] Could not auto-detect the menu command. Diagnostics below:"
echo "--- candidate paths referenced in install.sh ---"
printf '%s\n' "${REF_PATHS[@]}"
echo "--- executables created/modified during install ---"
printf '%s\n' "${NEW_BINS[@]}"
echo "--- matching systemd units ---"
systemctl list-unit-files 2>/dev/null | grep -i pengu || echo "(none found)"
