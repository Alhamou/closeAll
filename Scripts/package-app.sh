#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

swift build -c release --product closeAll

app="$root/build/closeAll.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/.build/release/closeAll" "$app/Contents/MacOS/closeAll"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$app/Contents/PkgInfo"
chmod +x "$app/Contents/MacOS/closeAll"
codesign --force --sign - "$app"
echo "Built $app"
