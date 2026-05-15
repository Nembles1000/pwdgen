#!/usr/bin/env bash
# pwdgen installer for Linux/macOS
# Usage: install.sh
#        install.sh --version vX.Y.Z
set -e

REPO="Nembles1000/pwdgen"
GITHUB_API="https://api.github.com/repos/${REPO}"
PINNED_VERSION=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --version|-v)
      PINNED_VERSION="$2"
      shift; shift
      ;;
    *)
      echo "[fail] Unknown argument: $1"
      exit 1
      ;;
  esac
done

if ! command -v curl >/dev/null 2>&1 ; then
  echo "[fail] 'curl' is required but not found. Please install it first."
  exit 1
fi

if [[ -n "$PINNED_VERSION" ]]; then
  VERSION="$PINNED_VERSION"
  echo "[pwdgen] Using pinned version: $VERSION"
else
  echo "[pwdgen] Fetching latest version from GitHub..."
  VERSION="$(curl -fsSL "$GITHUB_API/releases/latest" | grep -oP '"tag_name":\s*"\K(.*?)(?=")')"
  if [[ -z "$VERSION" ]]; then
    echo "[ warn ] No GitHub release found, checking tags..."
    VERSION="$(curl -fsSL "$GITHUB_API/tags" | grep -oP '"name":\s*"\K(.*?)(?=")' | head -n 1)"
  fi
  if [[ -z "$VERSION" ]]; then
    echo "[fail] Could not determine version from GitHub releases or tags. Aborting."
    exit 1
  fi
  echo "[pwdgen] Latest version: $VERSION"
fi

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR" || { echo "[fail] Could not create install directory: $INSTALL_DIR"; exit 1; }

UNAME_OUT="$(uname -s)"
case "${UNAME_OUT}" in
    Linux*)     BINARY_NAME=pwdgen-linux;;
    Darwin*)    BINARY_NAME=pwdgen-macos;;
    *)          echo "[fail] Unsupported OS: ${UNAME_OUT}"; exit 1;;
esac

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_NAME}"
INSTALL_PATH="${INSTALL_DIR}/pwdgen"

echo "[pwdgen] Downloading $BINARY_NAME $VERSION..."
echo "[pwdgen] Source: $DOWNLOAD_URL"
curl -fsSL -o "${INSTALL_PATH}" "${DOWNLOAD_URL}" || { echo "[fail] Download failed. Check that version $VERSION exists."; exit 1; }
chmod +x "${INSTALL_PATH}"

echo "[  ok  ] Installed to ${INSTALL_PATH}"

# PATH check
echo "$PATH" | grep -q "$INSTALL_DIR" || {
  echo "[ warn ] $INSTALL_DIR is not on your PATH."
  echo "[ warn ] Add it to PATH, e.g. by running:"
  echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
}

# verify
if ! command -v pwdgen >/dev/null 2>&1 ; then
  echo "[ warn ] pwdgen installed but not found in PATH yet."
  echo "[ warn ] Restart your terminal or add $INSTALL_DIR to PATH."
else
  echo "[  ok  ] pwdgen is ready. Try: pwdgen 16"
fi

echo
echo "Done. pwdgen $VERSION installed."
echo
