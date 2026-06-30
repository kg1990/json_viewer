#!/bin/bash
# build_lib.sh — AC-1 build check.
# Compiles JSONCore into a dynamic library using swiftc directly (SwiftPM is
# broken in this CLT-only environment).
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p build

swiftc -emit-module -emit-library -o build/libJSONCore.dylib Sources/JSONCore/*.swift -lz

echo "BUILD OK: build/libJSONCore.dylib"
