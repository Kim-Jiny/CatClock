#!/bin/bash
# CatClock.app — Mac App Store 제출용 빌드.
#
# 사용:
#   ./build_app_mas.sh                       → ./CatClock-MAS.app 생성 (서명 시도)
#   ./build_app_mas.sh --pkg                 → 위 + CatClock.pkg (App Store Connect 업로드용)
#
# 사전 준비(1회):
#   1) Apple Developer Program 가입 ($99/년).
#   2) Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates 에서 발급:
#        - "Apple Distribution"               (.app 서명)
#        - "3rd Party Mac Developer Installer" (.pkg 서명)
#   3) App Store Connect 에서 새 앱 등록 (Bundle ID: com.jiny.catclock.mas).
#   4) 프로비저닝 프로파일은 자동/Xcode 관리(이 스크립트는 embedded.provisionprofile 을
#      $MAS_PROFILE 환경변수로 받으면 번들에 넣음 — 없어도 빌드 자체는 진행).
#
# 직접배포 빌드와 동시 진행하기 위해 산출물 이름을 분리(CatClock-MAS.app).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CatClock"
APP="${APP_NAME}-MAS.app"
BUNDLE_ID="com.jiny.catclock.mas"
ENTITLEMENTS="Resources/CatClock-MAS.entitlements"
INFO_PLIST="Resources/Info-MAS.plist"
PKG="CatClock-MAS.pkg"

MAKE_PKG=0
[[ "${1:-}" == "--pkg" ]] && MAKE_PKG=1

# --- 인증서 자동 탐색 (없으면 ad-hoc 으로 폴백해 빌드 검증만) ---
APP_SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -E '"(Apple Distribution|3rd Party Mac Developer Application)' \
  | head -1 | awk -F'"' '{print $2}' || true)"

INSTALLER_SIGN_ID="$(security find-identity -v 2>/dev/null \
  | grep '3rd Party Mac Developer Installer' \
  | head -1 | awk -F'"' '{print $2}' || true)"

if [ -z "$APP_SIGN_ID" ]; then
  echo "⚠︎ Apple Distribution / 3rd Party Mac Developer Application 인증서 없음."
  echo "   ad-hoc 서명으로 빌드만 검증합니다. (스토어 업로드는 불가)"
  APP_SIGN_ID="-"
fi

echo "▶︎ 서명 ID(.app): $APP_SIGN_ID"
[ -n "$INSTALLER_SIGN_ID" ] && echo "▶︎ 서명 ID(.pkg): $INSTALLER_SIGN_ID"

# --- 1. release 빌드 (-D APPSTORE) ---
echo "▶︎ release 빌드 (CATCLOCK_APPSTORE=1)…"
CATCLOCK_APPSTORE=1 swift build -c release
BIN=".build/release/${APP_NAME}"
[ -x "$BIN" ] || { echo "✗ 빌드 산출물 없음: $BIN"; exit 1; }

# --- 2. .app 번들 구성 ---
echo "▶︎ ${APP} 번들 구성…"
rm -rf "$APP" "$PKG"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "$INFO_PLIST" "${APP}/Contents/Info.plist"
cp Resources/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"
cp "$BIN" "${APP}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP}/Contents/MacOS/${APP_NAME}"

# 임베디드 프로비저닝 프로파일이 있으면 복사
if [ -n "${MAS_PROFILE:-}" ] && [ -f "$MAS_PROFILE" ]; then
  cp "$MAS_PROFILE" "${APP}/Contents/embedded.provisionprofile"
  echo "▶︎ provisioning profile 임베드: $MAS_PROFILE"
fi

# 다운로드한 .provisionprofile 등에 붙은 com.apple.quarantine 등 확장 속성 제거.
# App Store 는 패키지 내 파일에 quarantine 속성이 있으면 91109 로 거부한다.
xattr -cr "$APP"

# --- 3. 서명 (hardened runtime 은 MAS 에서는 옵션이지만 권장) ---
echo "▶︎ 코드서명…"
if [ "$APP_SIGN_ID" = "-" ]; then
  # ad-hoc: 권한도 ad-hoc 으로만 적용 — 스토어 제출은 안 됨, 빌드 검증용.
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"
else
  codesign --force --options runtime --timestamp \
           --sign "$APP_SIGN_ID" \
           --entitlements "$ENTITLEMENTS" \
           "${APP}/Contents/MacOS/${APP_NAME}"
  codesign --force --options runtime --timestamp \
           --sign "$APP_SIGN_ID" \
           --entitlements "$ENTITLEMENTS" \
           "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi

echo "✓ ${APP} 준비 완료 ($(pwd)/${APP})"

# --- 4. (옵션) .pkg 생성 ---
if [ "$MAKE_PKG" -eq 1 ]; then
  if [ -z "$INSTALLER_SIGN_ID" ]; then
    echo "✗ '3rd Party Mac Developer Installer' 인증서가 없어 .pkg 생성 불가."
    exit 1
  fi
  echo "▶︎ ${PKG} 생성…"
  productbuild --component "$APP" /Applications \
               --sign "$INSTALLER_SIGN_ID" \
               "$PKG"
  echo "✓ ${PKG} 준비 완료 ($(pwd)/${PKG})"
  echo
  echo "다음 단계 — Transporter 또는 altool 로 App Store Connect 업로드:"
  echo "  xcrun altool --upload-app -f $PKG -t macos \\"
  echo "    --apple-id <APPLE_ID> --password <APP_SPECIFIC_PASSWORD>"
fi
