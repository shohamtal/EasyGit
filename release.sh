#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="EasyGit"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
TAP_REPO="shohamtal/homebrew-easygit"
TAP_DIR="/tmp/homebrew-easygit"

# --- Require version argument ---
if [ -z "$1" ]; then
    echo "Usage: ./release.sh <version>"
    echo "Example: ./release.sh 1.1.0"
    exit 1
fi

VERSION="$1"
TAG="v$VERSION"

echo "=== Releasing $APP_NAME $TAG ==="
echo ""

# --- Step 1: Build ---
echo "[1/5] Building release..."
rm -rf "$APP_BUNDLE"
"$SCRIPT_DIR/build.sh"

# --- Step 2: Zip ---
echo "[2/5] Creating zip..."
cd "$SCRIPT_DIR"
rm -f EasyGit.zip
zip -r EasyGit.zip EasyGit.app

# --- Step 3: GitHub release ---
echo "[3/5] Creating GitHub release $TAG..."
gh release create "$TAG" EasyGit.zip \
    --title "$APP_NAME $TAG" \
    --notes "Release $VERSION" \
    --repo "shohamtal/EasyGit"

echo "GitHub release created."

# --- Step 4: Get SHA256 ---
echo "[4/5] Computing SHA256..."
DOWNLOAD_URL="https://github.com/shohamtal/EasyGit/releases/download/$TAG/EasyGit.zip"
curl -sL -o /tmp/EasyGit-release.zip "$DOWNLOAD_URL"
SHA=$(shasum -a 256 /tmp/EasyGit-release.zip | awk '{print $1}')
rm -f /tmp/EasyGit-release.zip
echo "SHA256: $SHA"

# --- Step 5: Update Homebrew tap ---
echo "[5/5] Updating Homebrew tap..."
rm -rf "$TAP_DIR"
gh repo clone "$TAP_REPO" "$TAP_DIR" -- -q

CASK_FILE="$TAP_DIR/Casks/easygit.rb"
# Update version
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK_FILE"
# Update sha256
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA\"/" "$CASK_FILE"

cd "$TAP_DIR"
git add Casks/easygit.rb
git commit -m "Update EasyGit to $TAG"
git push

echo ""
echo "=== Done! ==="
echo "GitHub: https://github.com/shohamtal/EasyGit/releases/tag/$TAG"
echo "Brew:   brew upgrade --cask easygit"
