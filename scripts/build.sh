#!/bin/bash
# Собирает Launchpad+.app в build/ (без Xcode, только Command Line Tools)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64
BIN=$(swift build -c release --arch arm64 --show-bin-path)/LaunchpadPlus

APP=build/Launchpad+.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LaunchpadPlus"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Готово: $APP"
