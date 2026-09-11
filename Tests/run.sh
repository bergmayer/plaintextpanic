#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Override DEVELOPER_DIR to use another full Xcode installation.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
unset SDKROOT
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
TEST_DIR="$(mktemp -d /tmp/plaintextpanic-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
APP_DIR="$TEST_DIR/Regression.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp PlaintextPanic/Resources/WordLists/*.gz "$APP_DIR/Contents/Resources/"
SOURCES=(PlaintextPanic/*.swift PlaintextPanic/Models/*.swift PlaintextPanic/Services/*.swift PlaintextPanic/Views/*.swift)
for CONFIGURATION in release debug; do
    FLAGS=(-Onone)
    if [[ "$CONFIGURATION" == debug ]]; then FLAGS+=(-D DEBUG); fi
    xcrun swiftc -sdk "$SDK_PATH" -target "$(uname -m)-apple-macos14.0" \
        -D TESTING "${FLAGS[@]}" "${SOURCES[@]}" Tests/Regression.swift \
        -o "$APP_DIR/Contents/MacOS/Regression"
    "$APP_DIR/Contents/MacOS/Regression"
done
