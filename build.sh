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

echo "→ rendering AppIcon.iconset"
ICON_WORK="$(mktemp -d)"
ICONSET_DIR="${ICON_WORK}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

# The binary itself exports PNGs via --export-icon, so the icon drawing lives
# in one place (Sources/windowhop/WindowHopIcon.swift) for both app icon and
# menu bar use.
"${BIN_PATH}" --export-icon 16   "${ICONSET_DIR}/icon_16x16.png"
"${BIN_PATH}" --export-icon 32   "${ICONSET_DIR}/icon_16x16@2x.png"
"${BIN_PATH}" --export-icon 32   "${ICONSET_DIR}/icon_32x32.png"
"${BIN_PATH}" --export-icon 64   "${ICONSET_DIR}/icon_32x32@2x.png"
"${BIN_PATH}" --export-icon 128  "${ICONSET_DIR}/icon_128x128.png"
"${BIN_PATH}" --export-icon 256  "${ICONSET_DIR}/icon_128x128@2x.png"
"${BIN_PATH}" --export-icon 256  "${ICONSET_DIR}/icon_256x256.png"
"${BIN_PATH}" --export-icon 512  "${ICONSET_DIR}/icon_256x256@2x.png"
"${BIN_PATH}" --export-icon 512  "${ICONSET_DIR}/icon_512x512.png"
"${BIN_PATH}" --export-icon 1024 "${ICONSET_DIR}/icon_512x512@2x.png"

ICNS_PATH="${ICON_WORK}/AppIcon.icns"
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"

echo "→ assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${BIN_NAME}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
cp "${ICNS_PATH}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

rm -rf "${ICON_WORK}"

echo "→ ad-hoc codesign"
codesign --force --sign - "${APP_BUNDLE}"

echo
echo "✓ built ${PWD}/${APP_BUNDLE}"
echo
echo "install:"
echo "  mv \"${APP_BUNDLE}\" /Applications/"
echo "  open /Applications/${APP_BUNDLE}   # first launch — grant Accessibility"
echo
echo "trigger (after install):"
echo "  open -g windowhop://show"
