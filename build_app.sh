#!/bin/bash
# build_app.sh — D10
# Compiles JSONCore + the SwiftUI App into a runnable macOS .app bundle using
# swiftc directly (SwiftPM/xcodebuild are broken/unavailable in this CLT-only
# environment). Exits non-zero on compile failure.
set -euo pipefail

cd "$(dirname "$0")"

APP_DIR="build/JSONViewer.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
EXEC="$MACOS_DIR/JSONViewer"
PLIST="$APP_DIR/Contents/Info.plist"

# Clean and recreate the bundle skeleton.
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RES_DIR"

echo "Compiling JSONCore + App -> $EXEC"
swiftc -parse-as-library -o "$EXEC" \
    Sources/JSONCore/*.swift \
    Sources/App/*.swift

echo "COMPILE OK"

# Write Info.plist.
cat > "$PLIST" <<'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>JSONViewer</string>
    <key>CFBundleIdentifier</key>
    <string>com.jsonviewer.app</string>
    <key>CFBundleName</key>
    <string>JSONViewer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST_EOF

# Validate the plist.
plutil -lint "$PLIST"

echo "APP BUNDLE: $(cd "$(dirname "$APP_DIR")" && pwd)/$(basename "$APP_DIR")"
