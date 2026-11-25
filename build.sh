#!/bin/bash
# Build DisplayPro.app without Xcode (Command Line Tools only).
# Outputs build/DisplayPro.app, ad-hoc signed.

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="DisplayPro"
SRC_DIR="DisplayPro"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
MIN_OS="14.0"  # ScreenCaptureKit window screenshots need macOS 14
ARCH_TARGET="arm64-apple-macos${MIN_OS}"

rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Dock Preview + ⌘Tab window switcher sources.
WF_SOURCES=()
while IFS= read -r f; do WF_SOURCES+=("$f"); done < <(find "${SRC_DIR}/WindowFeatures" -name '*.swift' | sort)

# 1. Compile.
swiftc \
    -target "${ARCH_TARGET}" \
    -O \
    -parse-as-library \
    -module-name "${APP_NAME}" \
    "${SRC_DIR}/DisplayManager.swift" \
    "${SRC_DIR}/Services/WakeController.swift" \
    "${SRC_DIR}/DisplayProApp.swift" \
    "${WF_SOURCES[@]}" \
    -framework SwiftUI \
    -framework AppKit \
    -framework CoreGraphics \
    -framework ApplicationServices \
    -framework ScreenCaptureKit \
    -framework Carbon \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# 2. Bundle metadata.
cp "${SRC_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ${APP_NAME}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.${APP_NAME}" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.example.${APP_NAME}" "${APP_BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

# 3. Build the app icon from the .iconset folder and bundle it.
#    CFBundleIconFile in Info.plist points at this file (by name, no extension).
./make-icon.sh
cp "${SRC_DIR}/Resources/DisplayPro.icns" "${APP_BUNDLE}/Contents/Resources/"

# 4. Ad-hoc sign so Gatekeeper lets it launch.
codesign --force --sign - --entitlements "${SRC_DIR}/${APP_NAME}.entitlements" --options runtime "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE}"
