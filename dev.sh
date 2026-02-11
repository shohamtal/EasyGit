#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="EasyGit"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

# Kill running instance
echo "Stopping $APP_NAME..."
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 0.5

# Remove old app bundle
echo "Removing old app bundle..."
rm -rf "$APP_BUNDLE"

# Build
echo "Building..."
"$SCRIPT_DIR/build.sh"

# Launch
echo "Launching $APP_NAME..."
open "$APP_BUNDLE"
