#!/usr/bin/env sh
# pwdgen installer
# Supports: Linux, macOS
# Usage: sh install.sh
#        sh install.sh --version v1.2.0   (pin a specific version)

set -e

REPO="Nembles1000/pwdgen"
GITHUB_API="https://api.github.com/repos/${REPO}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}"

# ── colours ───────────────────────────────────────────────────────────────────
RED="\033[0;31m"
GRN="\033[0;32m"
YEL="\033[1;33m"
CYN="\033[0;36m"
RST="\033[0m"

info()  { printf "${CYN}[pwdgen]${RST} %s\n" "$*"; }
ok()    { printf "${GRN}[  ok  ]${RST} %s\n" "$*"; }
warn()  { printf "${YEL}[ warn ]${RST} %s\n" "$*"; }
die()   { printf "${RED}[ fail ]${RST} %s\n" "$*" >&2; exit 1; }

# ── argument parsing ──────────────────────────────────────────────────────────
PINNED_VERSION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --version|-v) PINNED_VERSION="$2"; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

# ── dependency check ──────────────────────────────────────────────────────────
need() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found. Please install it first."
}
need curl

# ── detect OS ─────────────────────────────────────────────────────────────────
detect_os() {
    case "$(uname -s 2>/dev/null)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        *)       die "Unsupported OS: $(uname -s). For Windows use install.bat." ;;
    esac
}

OS=$(detect_os)
info "Detected OS: ${OS}"

# ── resolve version ───────────────────────────────────────────────────────────
if [ -n "${PINNED_VERSION}" ]; then
    VERSION="${PINNED_VERSION}"
    info "Using pinned version: ${VERSION}"
else
    info "Fetching latest version from GitHub..."
    API_RESPONSE=$(curl -sf "${GITHUB_API}/releases/latest" 2>/dev/null) || true

    if [ -n "${API_RESPONSE}" ]; then
        VERSION=$(printf '%s' "${API_RESPONSE}" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    fi

    # Fallback: scrape tags if no releases exist yet
    if [ -z "${VERSION}" ]; then
        warn "No GitHub release found, checking tags..."
        TAGS_RESPONSE=$(curl -sf "${GITHUB_API}/tags" 2>/dev/null) || true
        VERSION=$(printf '%s' "${TAGS_RESPONSE}" | grep '"name"' | head -1 | sed 's/.*"name": *"\([^"]*\)".*/\1/')
    fi

    # Hardcoded fallback
    if [ -z "${VERSION}" ]; then
        warn "Could not determine version from GitHub, falling back to v1.0.0"
        VERSION="v1.0.0"
    fi

    info "Latest version: ${VERSION}"
fi

# ── resolve binary name & install path ───────────────────────────────────────
case "${OS}" in
    linux)
        BINARY_NAME="pwdgen"
        INSTALL_DIR="/usr/local/bin"
        INSTALL_PATH="${INSTALL_DIR}/pwdgen"
        ;;
    macos)
        BINARY_NAME="pwdgen-macOS"
        INSTALL_DIR="/usr/local/bin"
        INSTALL_PATH="${INSTALL_DIR}/pwdgen"
        ;;
esac

DOWNLOAD_URL="${RAW_BASE}/main/bin/${VERSION}/${BINARY_NAME}"

# ── download ──────────────────────────────────────────────────────────────────
TMPFILE=$(mktemp /tmp/pwdgen_XXXXXX)
trap 'rm -f "${TMPFILE}"' EXIT

info "Downloading ${BINARY_NAME} ${VERSION}..."
info "Source: ${DOWNLOAD_URL}"

HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "${TMPFILE}" "${DOWNLOAD_URL}" 2>/dev/null)
if [ "${HTTP_CODE}" != "200" ]; then
    die "Download failed (HTTP ${HTTP_CODE}). Check that version ${VERSION} exists in the repo."
fi

ok "Download complete."

# ── install ───────────────────────────────────────────────────────────────────
install_binary() {
    chmod +x "${TMPFILE}"

    if cp "${TMPFILE}" "${INSTALL_PATH}" 2>/dev/null; then
        chmod +x "${INSTALL_PATH}"
        ok "Installed to ${INSTALL_PATH}"
    else
        warn "No write permission to ${INSTALL_DIR}, trying sudo..."
        if command -v sudo >/dev/null 2>&1; then
            sudo cp "${TMPFILE}" "${INSTALL_PATH}"
            sudo chmod +x "${INSTALL_PATH}"
            ok "Installed to ${INSTALL_PATH} (via sudo)"
        elif command -v doas >/dev/null 2>&1; then
            doas cp "${TMPFILE}" "${INSTALL_PATH}"
            doas chmod +x "${INSTALL_PATH}"
            ok "Installed to ${INSTALL_PATH} (via doas)"
        else
            die "Cannot write to ${INSTALL_DIR}. Run the installer as root or install sudo/doas."
        fi
    fi
}

install_binary

# ── verify ────────────────────────────────────────────────────────────────────
if command -v pwdgen >/dev/null 2>&1; then
    ok "pwdgen is ready. Try: pwdgen 16"
else
    warn "pwdgen installed but not found in PATH yet."
    warn "You may need to restart your terminal or add ${INSTALL_DIR} to PATH."
fi

printf "\n${GRN}Done.${RST} pwdgen ${VERSION} installed on ${OS}.\n\n"
