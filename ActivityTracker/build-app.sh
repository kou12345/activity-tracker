#!/bin/bash
set -e

APP_NAME="Activity Tracker"
EXECUTABLE_NAME="ActivityTracker"
BUNDLE_ID="com.local.ActivityTracker"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building release..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📋 Copying executable..."
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/"

echo "📝 Copying Info.plist..."
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS_DIR/"

echo "✅ Build complete!"
echo ""
echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To open:"
echo "  open \"$APP_BUNDLE\""
