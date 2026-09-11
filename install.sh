#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "================================================="
echo "   ✨ Installing Happy Mac Notch to macOS ✨   "
echo "================================================="
echo ""

# 1. Check prerequisites
if ! command -v swift &> /dev/null; then
    echo "❌ Swift compiler not found."
    echo "👉 Please run: xcode-select --install"
    exit 1
fi

# 2. Build the release bundle
echo "🔨 Compiling release build..."
./build.sh

APP_NAME="NotchApp"
LOCAL_APP="$DIR/$APP_NAME.app"
DEST_DIR="/Applications"

if [ ! -w "$DEST_DIR" ]; then
    echo "⚠️  /Applications is not writable without sudo. Installing to ~/Applications..."
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi

DEST_APP="$DEST_DIR/$APP_NAME.app"

echo "📂 Installing to $DEST_APP..."

# 3. Terminate running instance
killall "$APP_NAME" 2>/dev/null || true
sleep 0.5

# 4. Copy app bundle
rm -rf "$DEST_APP"
cp -R "$LOCAL_APP" "$DEST_APP"

# 5. Clear quarantine attribute (Gatekeeper bypass)
echo "🛡️  Clearing Gatekeeper quarantine flags..."
xattr -cr "$DEST_APP" 2>/dev/null || true

# 6. Apply ad-hoc code signature
echo "✍️  Applying code signature..."
codesign --force --deep --sign - "$DEST_APP" 2>/dev/null || true

# 7. Launch
echo "🚀 Launching Happy Mac Notch..."
open "$DEST_APP"

echo ""
echo "================================================="
echo "   🎉 Installation Complete! Happy Mac Notch is Running!   "
echo "================================================="
echo ""
echo "📌 IMPORTANT PERMISSION CHECKLIST:"
echo "1. Accessibility Permission (Required for edge-touch hover):"
echo "   Go to: System Settings > Privacy & Security > Accessibility"
echo "   Ensure 'NotchApp' is switched ON."
echo ""
echo "2. Automation Permission (For Spotify / Apple Music controls):"
echo "   Click 'OK' or 'Allow' when macOS prompts to control Spotify/Music."
echo ""
echo "3. Launch at Login (Optional):"
echo "   Go to: System Settings > General > Login Items"
echo "   Click '+' and add NotchApp from /Applications."
echo ""
