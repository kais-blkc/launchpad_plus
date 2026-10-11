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

# Версия: переменная VERSION (в CI берётся из тега) или файл VERSION
VERSION=${VERSION:-$(tr -d '[:space:]' < VERSION)}
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

# Иконка приложения: Resources/AppIcon-source.png (1024x1024) -> форма macOS -> AppIcon.icns.
# Без исходника приложение собирается без иконки.
if [ -f Resources/AppIcon-source.png ]; then
    TMP=$(mktemp -d)
    ICONSET="$TMP/AppIcon.iconset"
    mkdir -p "$ICONSET"
    swift scripts/make_icon.swift Resources/AppIcon-source.png "$TMP/AppIcon.png"
    for size in 16 32 128 256 512; do
        sips -z $size $size "$TMP/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size*2)) $((size*2)) "$TMP/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
    rm -rf "$TMP"
fi
codesign --force --sign - "$APP"
echo "Готово: $APP"
