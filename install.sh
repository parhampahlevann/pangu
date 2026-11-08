#!/usr/bin/env bash
set -euo pipefail

URL="https://github.com/parhampahlevann/pangu/releases/download/v5.1.6/PenguTunnel-5.4.1-Offline-Fix1-linux-amd64.zip"
ZIP_NAME="PenguTunnel-5.4.1-Offline-Fix1-linux-amd64.zip"
DIR_NAME="PenguTunnel-5.4.1-Offline-Fix1-linux-amd64"

# اگر root نیستی، با sudo دوباره اجرا شود
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

# نصب وابستگی‌ها در صورت نبودن
need_pkgs=()
command -v unzip >/dev/null 2>&1 || need_pkgs+=(unzip)
command -v curl  >/dev/null 2>&1 || need_pkgs+=(curl)
if [[ ${#need_pkgs[@]} -gt 0 ]]; then
  echo "[*] Installing: ${need_pkgs[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y "${need_pkgs[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "${need_pkgs[@]}"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "${need_pkgs[@]}"
  else
    echo "[!] Package manager not found. Install manually: ${need_pkgs[*]}" >&2
    exit 1
  fi
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "[*] Downloading..."
curl -fL --retry 3 --connect-timeout 15 -o "$ZIP_NAME" "$URL"

echo "[*] Extracting..."
unzip -q -o "$ZIP_NAME"

if [[ ! -d "$DIR_NAME" ]]; then
  echo "[!] Directory $DIR_NAME not found after extraction." >&2
  exit 1
fi

cd "$DIR_NAME"
echo "[*] Running installer..."
bash install.sh --repair-existing

echo "[+] Done."
