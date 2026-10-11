#!/bin/bash
# Собирает приложение и упаковывает его в build/Launchpad-Plus-<версия>.dmg (+ контрольная сумма).
set -euo pipefail
cd "$(dirname "$0")/.."

export VERSION=${VERSION:-$(tr -d '[:space:]' < VERSION)}
scripts/build.sh

DMG="build/Launchpad-Plus-$VERSION.dmg"
STAGE=$(mktemp -d)
cp -R "build/Launchpad+.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # чтобы приложение можно было перетащить в «Программы»

rm -f "$DMG"
hdiutil create -volname "Launchpad+" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

(cd build && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Готово: $DMG"
