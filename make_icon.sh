#!/bin/bash
# Resources/appIcon.png(1024x1024) → Resources/AppIcon.icns 생성.
# 아이콘 이미지를 바꾼 뒤 이 스크립트를 돌리고 빌드하면 새 아이콘이 적용된다.
set -euo pipefail
cd "$(dirname "$0")"

SRC="Resources/appIcon.png"
OUT="Resources/AppIcon.icns"
[ -f "$SRC" ] || { echo "✗ $SRC 없음"; exit 1; }

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

# (size, filename) 쌍.
gen() { sips -z "$1" "$1" "$SRC" --out "$ICONSET/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
gen 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$(dirname "$ICONSET")"
echo "✓ $OUT 생성 완료 ($(sips -g pixelWidth "$SRC" | awk '/pixelWidth/{print $2}')px 원본에서)"
