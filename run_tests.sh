#!/bin/bash
# run_tests.sh — compiles JSONCore sources + the plain-Swift test runner into a
# temp binary with swiftc and runs it. Exits non-zero if any test fails.
set -euo pipefail

cd "$(dirname "$0")"

TMPBIN="$(mktemp -t jsoncore_tests).bin"
trap 'rm -f "$TMPBIN"' EXIT

swiftc -o "$TMPBIN" Sources/JSONCore/*.swift Tests/Runner/main.swift

"$TMPBIN"
