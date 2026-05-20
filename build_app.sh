#!/bin/bash
# CatClock.app 번들 생성/갱신 스크립트.
#   ./build_app.sh            → ./CatClock.app 생성·갱신
#   ./build_app.sh --install  → 위 + /Applications 에 설치
#
# 평소 개발은 `swift run`. 실제로 쓸 버전이 되면 이 스크립트 한 번 돌리면 됨.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CatClock"
APP="${APP_NAME}.app"
BUNDLE_ID="com.jiny.catclock"

echo "▶︎ release 빌드…"
swift build -c release
BIN=".build/release/${APP_NAME}"
[ -x "$BIN" ] || { echo "✗ 빌드 산출물 없음: $BIN"; exit 1; }

echo "▶︎ ${APP} 번들 구성…"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp Resources/Info.plist "${APP}/Contents/Info.plist"
cp Resources/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"
cp "$BIN" "${APP}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP}/Contents/MacOS/${APP_NAME}"

# 로그인 항목/권한이 안정적으로 유지되도록 ad-hoc 서명.
echo "▶︎ ad-hoc 코드서명…"
codesign --force --deep --sign - "$APP"

echo "✓ ${APP} 준비 완료 ($(pwd)/${APP})"

if [[ "${1:-}" == "--install" ]]; then
    DEST="/Applications/${APP}"
    echo "▶︎ /Applications 에 설치…"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "✓ 설치 완료: ${DEST}"
    echo "  (이미 실행 중이면 종료 후 Launchpad/Finder에서 다시 실행)"
fi
