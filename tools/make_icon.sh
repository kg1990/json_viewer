#!/bin/bash
# Builds Resources/AppIcon.icns from the Core Graphics icon generator.
# Reproducible: regenerates the 1024 master, all iconset sizes, then the .icns.
set -euo pipefail
cd "$(dirname "$0")/.."

MASTER=/tmp/AppIcon-1024.png
ICONSET=/tmp/AppIcon.iconset
OUT_DIR=Resources
OUT="$OUT_DIR/AppIcon.icns"

echo "Compiling icon generator..."
swiftc tools/IconGen/main.swift -o /tmp/icongen
/tmp/icongen "$MASTER"

echo "Generating iconset sizes..."
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
sips -z 16 16     "$MASTER" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$MASTER" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$MASTER" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$MASTER" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$MASTER" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$MASTER" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$MASTER" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$MASTER" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$MASTER" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$MASTER"                "$ICONSET/icon_512x512@2x.png"

echo "Building .icns..."
mkdir -p "$OUT_DIR"
iconutil -c icns "$ICONSET" -o "$OUT"
echo "ICON OK: $OUT"
ls -la "$OUT"
