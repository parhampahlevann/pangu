#!/usr/bin/env bash
set -euo pipefail

URL="https://github.com/parhampahlevann/pangu/releases/download/v5.1.6/PenguTunnel-5.4.1-Offline-Fix1-linux-amd64.zip"
D="/opt/pengupanel-install"

if [[ $EUID -ne 0 ]]; then
  echo "[!] Run as root: sudo bash -c \"\$(curl -fsSL <SCRIPT_URL>)\"" >&2
  exit 1
fi

need=()
command -v unzip >/dev/null 2>&1 || need+=(unzip)
command -v curl  >/dev/null 2>&1 || need+=(curl)
if [[ ${#need[@]} -gt 0 ]]; then
  if   command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y "${need[@]}"
  elif command -v dnf     >/dev/null 2>&1; then dnf install -y "${need[@]}"
  elif command -v yum     >/dev/null 2>&1; then yum install -y "${need[@]}"
  else echo "[!] Install manually: ${need[*]}" >&2; exit 1; fi
fi

TTY_IN=/dev/null
[[ -r /dev/tty ]] && TTY_IN=/dev/tty

rm -rf "$D"; mkdir -p "$D"; cd "$D"

echo "[*] Downloading..."
curl -fL --retry 3 --connect-timeout 15 -o pengu.zip "$URL"
unzip -oq pengu.zip

# پیدا کردن خودکار پوشه‌ای که install.sh داخلش است
INSTALLER="$(find "$D" -maxdepth 3 -name install.sh -type f | head -n 1)"
if [[ -z "$INSTALLER" ]]; then
  echo "[!] install.sh not found inside the zip." >&2
  exit 1
fi
cd "$(dirname "$INSTALLER")"
chmod +x install.sh

echo "[*] Installing / repairing..."
bash install.sh --repair-existing < "$TTY_IN"

# اگر دستور منو نصب شده بود، اجرایش کن
for c in pengu pangu penguctl pengupanel pengu-panel; do
  if command -v "$c" >/dev/null 2>&1; then
    exec "$c" < "$TTY_IN"
  fi
done

# در غیر این صورت، منوی خود installer
exec bash install.sh < "$TTY_IN"
