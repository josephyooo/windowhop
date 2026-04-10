#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WindowHop"
APP_BUNDLE="${APP_NAME}.app"
BIN_NAME="windowhop"
BUILD_CONFIG="${BUILD_CONFIG:-release}"

cd "$(dirname "$0")"

echo "→ swift build -c ${BUILD_CONFIG}"
swift build -c "${BUILD_CONFIG}"

BIN_PATH="$(swift build -c "${BUILD_CONFIG}" --show-bin-path)/${BIN_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
    echo "error: built binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "→ assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${BIN_NAME}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"

echo "→ ad-hoc codesign"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo
echo "✓ built ${PWD}/${APP_BUNDLE}"
echo
echo "install:"
echo "  mv \"${APP_BUNDLE}\" /Applications/"
echo "  open /Applications/${APP_BUNDLE}   # first launch — grant Accessibility"
echo
echo "trigger (after install):"
echo "  open -g windowhop://show"
