#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "🔨 Building NotchApp with Swift..."
mkdir -p .build/cache

swift build -c release \
  -Xswiftc -module-cache-path -Xswiftc "$DIR/.build/cache" \
  -Xcc -fmodules-cache-path="$DIR/.build/cache"

APP_NAME="NotchApp"
APP_BUNDLE="$DIR/$APP_NAME.app"

echo "📦 Packaging into $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NotchApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.happymac.notch</string>
    <key>CFBundleName</key>
    <string>HappyMacNotch</string>
    <key>CFBundleDisplayName</key>
    <string>Happy Mac Notch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Happy Mac Notch displays track info and album art from Spotify and Apple Music in your notch.</string>
    <key>NSCameraUsageDescription</key>
    <string>Happy Mac Notch uses your FaceTime HD camera for the Quick Selfie mirror booth.</string>
</dict>
</plist>
EOF

echo "✍️  Applying ad-hoc code signature..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "✅ Done! $APP_NAME.app is ready."
echo "👉 To launch: open $APP_NAME.app"
