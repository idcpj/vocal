#!/bin/bash
set -e

APP_NAME="VocalHost"
BUILD_DIR="build_macos"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "🚀 Starting build process for ${APP_NAME}..."

# Clean and create directory structure
rm -rf "$BUILD_DIR"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "📦 Compiling Swift source..."
swiftc -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" mac/VocalHostApp.swift -parse-as-library

echo "📄 Copying Info.plist and Icon..."
cp mac/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
cp mac/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "🔐 Code signing..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}')
if [ -n "$SIGNING_IDENTITY" ]; then
    echo "Using development identity: ${SIGNING_IDENTITY}"
    codesign --force --deep --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"
else
    echo "Using ad-hoc signing..."
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "💿 Creating DMG..."
DMG_STAGING_DIR="${BUILD_DIR}/dmg_staging"
mkdir -p "${DMG_STAGING_DIR}"
mv "${APP_BUNDLE}" "${DMG_STAGING_DIR}/"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
hdiutil create -volname "${APP_NAME} Installer" -srcfolder "${DMG_STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"

echo "✅ Build complete! DMG available at: ${DMG_PATH}"
