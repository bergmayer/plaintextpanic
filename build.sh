#!/bin/bash

# Build script for Plaintext Panic
# Usage: ./build.sh [debug|release|clean]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCODE_PROJECT="$PROJECT_DIR/PlaintextPanic.xcodeproj"
SCHEME="PlaintextPanic"
DERIVED_DATA="$PROJECT_DIR/build"
ICON_SOURCE="$PROJECT_DIR/PlaintextPanic/Resources/icon.png"

# Function to create app icon from PNG
create_app_icon() {
    local APP_PATH="$1"
    local ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"

    if [ -f "$ICON_SOURCE" ]; then
        echo "Creating app icon..."

        # Create temporary iconset directory
        ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
        mkdir -p "$ICONSET_DIR"

        # Generate all required icon sizes
        sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
        sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
        sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
        sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
        sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
        sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
        sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
        sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
        sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
        sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

        # Convert iconset to icns
        iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"

        # Clean up
        rm -rf "$(dirname "$ICONSET_DIR")"

        # Update Info.plist to reference the icon
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_PATH/Contents/Info.plist"

        # Re-sign the app after modifications (ad-hoc signing for development)
        echo "Re-signing app..."
        codesign --force --deep --sign - "$APP_PATH"

        echo "App icon created successfully."
    else
        echo "Warning: Icon source not found at $ICON_SOURCE"
    fi
}

case "${1:-debug}" in
    debug)
        echo "Building Debug configuration..."
        xcodebuild \
            -project "$XCODE_PROJECT" \
            -scheme "$SCHEME" \
            -configuration Debug \
            -derivedDataPath "$DERIVED_DATA" \
            build

        APP_PATH="$DERIVED_DATA/Build/Products/Debug/PlaintextPanic.app"
        create_app_icon "$APP_PATH"

        echo ""
        echo "Build succeeded!"
        echo "App location: $APP_PATH"
        ;;

    release)
        echo "Building Release configuration..."
        xcodebuild \
            -project "$XCODE_PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -derivedDataPath "$DERIVED_DATA" \
            build

        APP_PATH="$DERIVED_DATA/Build/Products/Release/PlaintextPanic.app"
        create_app_icon "$APP_PATH"

        echo ""
        echo "Build succeeded!"
        echo "App location: $APP_PATH"
        ;;

    clean)
        echo "Cleaning build artifacts..."
        xcodebuild \
            -project "$XCODE_PROJECT" \
            -scheme "$SCHEME" \
            -derivedDataPath "$DERIVED_DATA" \
            clean
        rm -rf "$DERIVED_DATA"
        echo "Clean complete."
        ;;

    *)
        echo "Usage: $0 [debug|release|clean]"
        echo ""
        echo "Commands:"
        echo "  debug   - Build debug configuration (default)"
        echo "  release - Build release configuration"
        echo "  clean   - Clean build artifacts"
        exit 1
        ;;
esac
