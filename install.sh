#!/usr/bin/env bash
#
# PenguPanel Auto-Installer
# دانلود، نصب (repair-existing) و نمایش منوی مدیریت به‌صورت خودکار
#
set -euo pipefail

# ---------------------------------------------------------------------------
# تنظیمات
# ---------------------------------------------------------------------------
PKG_URL="https://github.com/parhampahlevann/pangu/releases/download/v5.1.6/pengu.zip"
WORK_DIR="/opt/pengupanel-install"
ZIP_NAME="pengu.zip"
INSTALL_SCRIPT_REL="PenguPanel/install.sh"

# نام‌های احتمالی دستور سراسری که ممکن است نصب‌کننده بسازد
MENU_COMMAND_CANDIDATES=(pengu pangu penguctl pengupanel pengu-panel)

# ---------------------------------------------------------------------------
# توابع کمکی برای خروجی رنگی
# ---------------------------------------------------------------------------
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[1;33m'
C_RESET='\033[0m'

log()  { echo -e "${C_GREEN}[+]${C_RESET} $1"; }
warn() { echo -e "${C_YELLOW}[!]${C_RESET} $1"; }
err()  { echo -e "${C_RED}[x]${C_RESET} $1" >&2; }

# ---------------------------------------------------------------------------
# بررسی دسترسی root
# ---------------------------------------------------------------------------
if [[ ${EUID} -ne 0 ]]; then
    err "این اسکریپت باید با دسترسی root اجرا شود. مثال: sudo bash install.sh"
    exit 1
fi

# ---------------------------------------------------------------------------
# نصب پیش‌نیازها (curl, unzip)
# ---------------------------------------------------------------------------
install_prereqs() {
    local missing=()
    for cmd in curl unzip; do
        command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "نصب پیش‌نیازهای مورد نیاز: ${missing[*]}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq
            apt-get install -y "${missing[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing[@]}"
        else
            err "پکیج‌منیجر شناخته‌شده‌ای پیدا نشد. لطفاً ${missing[*]} را دستی نصب کنید."
            exit 1
        fi
    fi
}

# ---------------------------------------------------------------------------
# دانلود و استخراج بسته
# ---------------------------------------------------------------------------
download_and_extract() {
    mkdir -p "${WORK_DIR}"
    cd "${WORK_DIR}"

    log "در حال دانلود بسته از:"
    echo "      ${PKG_URL}"
    if ! curl -fL --retry 3 --retry-delay 2 -o "${ZIP_NAME}" "${PKG_URL}"; then
        err "دانلود فایل ناموفق بود. اتصال اینترنت یا آدرس را بررسی کنید."
        exit 1
    fi

    log "در حال استخراج فایل..."
    unzip -oq "${ZIP_NAME}"

    if [[ ! -f "${INSTALL_SCRIPT_REL}" ]]; then
        err "فایل ${INSTALL_SCRIPT_REL} پس از استخراج پیدا نشد."
        exit 1
    fi
    chmod +x "${INSTALL_SCRIPT_REL}"
}

# ---------------------------------------------------------------------------
# اجرای نصب‌کننده اصلی
# ---------------------------------------------------------------------------
run_installer() {
    log "در حال اجرای نصب‌کننده با گزینه --repair-existing ..."
    bash "${INSTALL_SCRIPT_REL}" --repair-existing
    log "نصب / تعمیر با موفقیت به پایان رسید."
}

# ---------------------------------------------------------------------------
# نمایش منوی مدیریت پس از نصب
# ---------------------------------------------------------------------------
show_menu() {
    log "در حال باز کردن منوی مدیریت..."

    # اگر نصب‌کننده یک دستور سراسری در PATH ساخته باشد، همان اجرا می‌شود
    for cmd in "${MENU_COMMAND_CANDIDATES[@]}"; do
        if command -v "${cmd}" >/dev/null 2>&1; then
            exec "${cmd}"
        fi
    done

    # در غیر این صورت، خود install.sh بدون فلگ اجرا می‌شود
    # (در بسیاری از این پنل‌ها اجرای دوباره‌ی اسکریپت، منوی مدیریت را نشان می‌دهد)
    if [[ -f "${INSTALL_SCRIPT_REL}" ]]; then
        bash "${INSTALL_SCRIPT_REL}"
    else
        warn "دستور یا اسکریپت منو پیدا نشد؛ نصب کامل شد ولی منو به‌صورت خودکار باز نشد."
        warn "می‌توانید دستی از مسیر زیر اجرا کنید:"
        echo "      ${WORK_DIR}/${INSTALL_SCRIPT_REL}"
    fi
}

main() {
    install_prereqs
    download_and_extract
    run_installer
    show_menu
}

main "$@"
