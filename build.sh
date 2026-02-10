#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="EasyGit"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUILD_DIR="$SCRIPT_DIR/$APP_NAME"

echo "Building $APP_NAME..."
cd "$BUILD_DIR"
swift build -c release 2>&1 | grep -v "could not determine XCTest"

# Find the binary (supports both arm64 and x86_64)
BINARY=$(find .build -path "*/release/$APP_NAME" -type f | head -1)
if [ -z "$BINARY" ]; then
    echo "Error: Build binary not found"
    exit 1
fi
echo "Binary: $BINARY"

# Create .app bundle structure
echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>EasyGit</string>
    <key>CFBundleIdentifier</key>
    <string>com.easygit.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>EasyGit</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo ""
echo "Done! $APP_NAME.app is ready."
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To zip:  zip -r EasyGit.zip EasyGit.app"
