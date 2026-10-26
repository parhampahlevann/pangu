#!/usr/bin/env bash
# PenguTunnel bootstrap installer
# One-command run: download + extract + execute the real install.sh
set -euo pipefail

# ---------------- Config ----------------
VERSION="v4.2.1"
ZIP_NAME="PenguTunnel-${VERSION}.zip"
EXTRACT_DIR="PenguTunnel-4.2.1"   # folder name inside the zip (no "v")
DOWNLOAD_URL="https://github.com/parhampahlevann/pangu/releases/download/${VERSION}/${ZIP_NAME}"
WORK_DIR="/tmp/pangu-install-$$"

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

    if [ ! -d "$EXTRACT_DIR" ]; then
        echo "[!] Folder $EXTRACT_DIR not found after extraction. Archive contents:"
        ls -la
        exit 1
    fi

    cd "$EXTRACT_DIR"

    if [ ! -f "install.sh" ]; then
        echo "[!] install.sh not found inside the package."
        exit 1
    fi

    echo "[*] Running the PenguTunnel installer..."
    chmod +x install.sh
    bash install.sh

    echo "[+] Installation complete."
}

main "$@"
