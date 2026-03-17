#!/bin/bash
# run_app_shell_macos.sh
# Baut LocationHistoryConsumerApp und startet sie als foreground macOS App.
#
# Verwendung:
#   ./scripts/run_app_shell_macos.sh
#
# Das Script erstellt eine minimale .app-Bundle-Struktur im .build/-Verzeichnis,
# damit macOS die App als foreground-Fenster behandelt statt als background-Prozess.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="LocationHistoryConsumerApp"
APP_BUNDLE_DIR="$REPO_ROOT/.build/AppBundle"
APP_PATH="$APP_BUNDLE_DIR/$PRODUCT.app"

echo "==> Building $PRODUCT ..."
cd "$REPO_ROOT"
swift build --product "$PRODUCT"

# Binary-Pfad aus swift build ermitteln
BINARY_PATH="$(swift build --product "$PRODUCT" --show-bin-path)/$PRODUCT"

if [ ! -f "$BINARY_PATH" ]; then
    echo "ERROR: Binary not found at $BINARY_PATH"
    exit 1
fi

echo "==> Creating minimal .app bundle ..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"

cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$PRODUCT"

cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LocationHistoryConsumerApp</string>
    <key>CFBundleIdentifier</key>
    <string>de.roeber.LocationHistoryConsumerApp.dev</string>
    <key>CFBundleName</key>
    <string>LocationHistoryConsumerApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

echo "==> Launching $PRODUCT.app ..."
open "$APP_PATH"

echo "==> Done. App bundle at: $APP_PATH"
