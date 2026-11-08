#!/usr/bin/env bash
set -euo pipefail

URL="https://github.com/parhampahlevann/pangu/releases/download/v5.1.6/PenguTunnel-5.4.1-Offline-Fix1-linux-amd64.zip"
ZIP_NAME="PenguTunnel-5.4.1-Offline-Fix1-linux-amd64.zip"
DIR_NAME="PenguTunnel-5.4.1-Offline-Fix1-linux-amd64"
MENU_CMD="pengu"   # <-- اسم واقعی دستور منو را اینجا بگذار

if [[ $EUID -ne 0 ]]; then
  echo "[!] Run as root: sudo bash -c \"\$(curl -fsSL <URL>)\"" >&2
  exit 1
fi

need=()
command -v unzip >/dev/null || need+=(unzip)
command -v curl  >/dev/null || need+=(curl)
if [[ ${#need[@]} -gt 0 ]]; then
  if command -v apt-get >/dev/null; then apt-get update -y && apt-get install -y "${need[@]}"
  elif command -v dnf >/dev/null; then dnf install -y "${need[@]}"
  elif command -v yum >/dev/null; then yum install -y "${need[@]}"
  else echo "[!] Install manually: ${need[*]}" >&2; exit 1; fi
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "[*] Downloading..."
curl -fL --retry 3 --connect-timeout 15 -o "$ZIP_NAME" "$URL"
unzip -q -o "$ZIP_NAME"
cd "$DIR_NAME"

# stdin را به ترمینال وصل می‌کنیم تا بخش‌های تعاملی کار کنند
TTY_IN=/dev/null
[[ -r /dev/tty ]] && TTY_IN=/dev/tty

echo "[*] Running installer..."
bash install.sh --repair-existing < "$TTY_IN"

echo "[+] Install finished."
cd /
if command -v "$MENU_CMD" >/dev/null 2>&1; then
  exec "$MENU_CMD" < "$TTY_IN"
else
  echo "[!] Menu command '$MENU_CMD' not found. Set MENU_CMD to the correct name."
fi
