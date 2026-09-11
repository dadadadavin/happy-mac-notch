#!/usr/bin/env bash
set -e

echo "🛑 Uninstalling Happy Mac Notch..."
killall NotchApp 2>/dev/null || true

rm -rf "/Applications/NotchApp.app"
rm -rf "$HOME/Applications/NotchApp.app"

echo "✅ Happy Mac Notch has been successfully removed."
