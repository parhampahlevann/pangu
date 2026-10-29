#!/usr/bin/env bash
# PenguTunnel bootstrap installer
# One-command run: download + extract + execute the real install.sh
set -euo pipefail

# ---------------- Config ----------------
VERSION="v5.0.4"
ZIP_NAME="PenguTunnel-${VERSION}-Offline.zip"
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

# Find the directory the zip extracted into, without assuming its exact name
# (the "-Offline" release may not unpack to the same folder-name pattern as
# earlier versions did).
detect_extract_dir() {
    local candidate
    # Most likely names first
    for candidate in "PenguTunnel-${VERSION#v}" "PenguTunnel-${VERSION}" "PenguTunnel-${VERSION#v}-Offline" "PenguTunnel-${VERSION}-Offline"; do
        if [ -d "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    # Fallback: the only top-level directory produced by extraction
    find . -mindepth 1 -maxdepth 1 -type d | head -n1
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

    local extract_dir
    extract_dir="$(detect_extract_dir)"

    if [ -z "$extract_dir" ] || [ ! -d "$extract_dir" ]; then
        echo "[!] Could not find the extracted folder. Archive contents:"
        ls -la
        exit 1
    fi

    cd "$extract_dir"

    if [ ! -f "install.sh" ]; then
        echo "[!] install.sh not found inside the package. Contents of $extract_dir:"
        ls -la
        exit 1
    fi

    echo "[*] Running the PenguTunnel installer..."
    chmod +x install.sh
    bash install.sh

    echo "[+] Installation complete."
}

main "$@"
