#!/bin/bash
# CatClock 배포용: Developer ID 서명 → 공증 → 스테이플 → DMG(드래그 설치) → DMG 공증/스테이플.
# 사전 준비(1회, 직접):
#   1) Developer ID Application 인증서 발급·설치
#      Xcode ▸ Settings ▸ Accounts ▸ (계정) ▸ Manage Certificates ▸ + ▸ "Developer ID Application"
#      (또는 https://developer.apple.com/account ▸ Certificates 에서 생성 후 더블클릭 설치)
#   2) 공증 자격증명 등록(키체인 프로필):
#      xcrun notarytool store-credentials CatClockNotary \
#         --apple-id "<애플ID 이메일>" --team-id "<TEAMID>" --password "<앱암호>"
#      (앱암호 = appleid.apple.com ▸ 로그인&보안 ▸ 앱 암호 에서 생성)
#
# 사용: ./release_dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CatClock"
APP="${APP_NAME}.app"
# Launch Services 캐시 충돌 회피를 위해 볼륨 이름은 앱 이름과 구분.
VOL="Install ${APP_NAME}"
DMG="${APP_NAME}.dmg"
SPARKLE_ZIP="${APP_NAME}.zip"               # Sparkle 자동 업데이트 자산
SPARKLE_SIG_OUT="${APP_NAME}-sparkle.sig"   # release.sh 가 읽어 appcast 에 박는 EdDSA 서명 라인
NOTARY_PROFILE="${NOTARY_PROFILE:-CatClockNotary}"
SPARKLE_VERSION="2.9.2"
SPARKLE_CACHE="${HOME}/Library/Application Support/CatClock/sparkle-${SPARKLE_VERSION}"

# --- Sparkle 도구·프레임워크 부트스트랩 ---
ensure_sparkle() {
  if [ ! -x "${SPARKLE_CACHE}/bin/sign_update" ]; then
    echo "▶︎ Sparkle ${SPARKLE_VERSION} 도구 다운로드…"
    mkdir -p "$SPARKLE_CACHE"
    curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
      -o "${SPARKLE_CACHE}/sparkle.tar.xz"
    tar -xf "${SPARKLE_CACHE}/sparkle.tar.xz" -C "$SPARKLE_CACHE"
    rm "${SPARKLE_CACHE}/sparkle.tar.xz"
  fi
  SPARKLE_BIN="${SPARKLE_CACHE}/bin"
}
ensure_sparkle

# --- Developer ID Application 인증서 자동 탐색 ---
DEV_ID_LINE="$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 || true)"
if [ -z "$DEV_ID_LINE" ]; then
  echo "✗ 'Developer ID Application' 인증서가 키체인에 없습니다."
  echo "  Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + ▸ Developer ID Application 으로 발급하세요."
  exit 1
fi
DEV_ID="$(echo "$DEV_ID_LINE" | awk -F'"' '{print $2}')"
echo "▶︎ 서명 ID: $DEV_ID"

# --- 1. release 빌드 + 번들 ---
echo "▶︎ release 빌드…"
swift build -c release
BIN=".build/release/${APP_NAME}"
[ -x "$BIN" ] || { echo "✗ 빌드 산출물 없음"; exit 1; }

rm -rf "$APP" "$DMG" "$SPARKLE_ZIP" "$SPARKLE_SIG_OUT"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources" "${APP}/Contents/Frameworks"
cp Resources/Info.plist "${APP}/Contents/Info.plist"
cp Resources/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"
cp "$BIN" "${APP}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP}/Contents/MacOS/${APP_NAME}"

# SwiftPM 리소스 번들(기본 고양이 이미지 등) 복사. 빠지면 기본 고양이가 사라진다.
for b in .build/release/*.bundle; do
    [ -e "$b" ] && cp -R "$b" "${APP}/Contents/Resources/"
done

# Sparkle.framework 임베드: SwiftPM 은 .app 번들 임베딩을 안 해줘서 수동 복사.
SPARKLE_FW_SRC=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[ -d "$SPARKLE_FW_SRC" ] || { echo "✗ Sparkle.framework 빌드 산출물 없음: $SPARKLE_FW_SRC"; exit 1; }
ditto "$SPARKLE_FW_SRC" "${APP}/Contents/Frameworks/Sparkle.framework"

# SwiftPM 산출물 바이너리에는 @executable_path/../Frameworks rpath 가 없어
# Contents/Frameworks/Sparkle.framework 를 못 찾는다. 서명 전에 추가.
install_name_tool -add_rpath "@executable_path/../Frameworks" \
                  "${APP}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# --- 2. Developer ID 서명 (하드닝 런타임 + 타임스탬프) ---
# Sparkle 권장 순서: 안쪽(helper·xpc) → framework → main 실행파일 → .app
echo "▶︎ 코드서명(hardened runtime)…"
SPARKLE_FW="${APP}/Contents/Frameworks/Sparkle.framework"
SPARKLE_VER_DIR="${SPARKLE_FW}/Versions/B"
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
         "${SPARKLE_VER_DIR}/XPCServices/Installer.xpc"
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
         "${SPARKLE_VER_DIR}/XPCServices/Downloader.xpc"
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
         "${SPARKLE_VER_DIR}/Autoupdate"
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
         "${SPARKLE_VER_DIR}/Updater.app"
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
         "$SPARKLE_FW"
# 리소스 번들(고양이 이미지)은 코드가 없는 플랫 번들이라 따로 서명하지 않는다.
# 아래 .app 전체 서명 시 리소스로 함께 봉인된다.
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
         "${APP}/Contents/MacOS/${APP_NAME}"
codesign --force --options runtime --timestamp --sign "$DEV_ID" \
         "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# --- 3. .app 공증 (zip 제출) ---
echo "▶︎ 공증 제출(.app)… 수 분 소요"
ZIP="${APP_NAME}-notarize.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$ZIP"
echo "▶︎ 스테이플(.app)…"
xcrun stapler staple "$APP"

# --- 3.5. Sparkle 자동 업데이트용 ZIP + EdDSA 서명 ---
# 공증·스테이플된 .app 을 ZIP 으로 묶고 sign_update 로 EdDSA 서명을 생성.
# ZIP 자체는 공증 불필요 — Sparkle 이 풀어서 공증된 .app 을 검증한다.
echo "▶︎ Sparkle ZIP + EdDSA 서명…"
ditto -c -k --keepParent "$APP" "$SPARKLE_ZIP"
# sign_update 출력 예: sparkle:edSignature="..." length="..."
"$SPARKLE_BIN/sign_update" "$SPARKLE_ZIP" > "$SPARKLE_SIG_OUT"
echo "  서명 라인: $(cat "$SPARKLE_SIG_OUT")"

# --- 4. DMG 구성 (드래그해서 Applications 로) ---
echo "▶︎ DMG 생성…"

# 이전 실행의 잔여 마운트 정리. "Install CatClock", "Install CatClock 1" 등 변종 포함.
# 남아있으면 convert 가 디스크 이미지를 못 읽고 실패한다.
shopt -s nullglob
for stale in "/Volumes/$VOL"*; do
  [ -d "$stale" ] || continue
  echo "  잔여 마운트 정리: $stale"
  hdiutil detach "$stale" -force >/dev/null 2>&1 \
    || diskutil eject "$stale" >/dev/null 2>&1 || true
done
shopt -u nullglob

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# 배경 이미지: 루트에 점파일로 두면 Finder에서 숨겨짐.
cp Resources/dmg_background.png "$STAGE/.bg.png"

RW_DMG="$(mktemp -u).dmg"
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ \
  -format UDRW -ov "$RW_DMG" >/dev/null
# 잔여 마운트가 남아있으면 hdiutil 이 자동 번호("Install CatClock 1")로 마운트한다.
# 그 경우 하드코딩한 "$VOL" 로 AppleScript/chflags 가 엉뚱한 볼륨을 건드려
# .DS_Store 가 빈 채로 convert 되어 install 창 레이아웃·배경이 통째로 깨진다.
# 실제 마운트 경로를 hdiutil 출력에서 받아 일관되게 쓴다.
ATTACH_OUT="$(hdiutil attach "$RW_DMG" -nobrowse)"
MNT="$(echo "$ATTACH_OUT" | awk -F'\t' '/Apple_HFS|Apple_APFS/ {print $NF}' | tail -1 | sed 's/[[:space:]]*$//')"
[ -d "$MNT" ] || { echo "✗ 마운트 경로를 확정하지 못했습니다: '$MNT'"; echo "$ATTACH_OUT"; exit 1; }
DISKNAME="$(basename "$MNT")"
if [ "$DISKNAME" != "$VOL" ]; then
  echo "  ⚠︎ 잔여 마운트로 자동 번호됨: '$DISKNAME' (기대: '$VOL'). 진행은 계속."
fi

# 창 레이아웃: 한글 안내 배경 + 앱(좌) / Applications(우) (드래그 유도)
# AppleScript 실패는 곧 install 창이 깨진다는 뜻이므로 절대 || true 로 삼키지 않는다.
osascript <<EOF
tell application "Finder"
  tell disk "$DISKNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    -- 540 x 380 (Resources/dmg_background.png 와 정확히 일치)
    set the bounds of container window to {200, 120, 740, 500}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set text size of theViewOptions to 12
    set background picture of theViewOptions to file ".bg.png"
    -- 배경의 화살표(중심 x=275, y=240) 좌우로 대칭 배치
    set position of item "${APP}" of container window to {145, 240}
    set position of item "Applications" of container window to {405, 240}
    -- 배경 이미지는 창 바깥 좌표로 보내 어떤 환경에서도 보이지 않게.
    set position of item ".bg.png" of container window to {900, 900}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
sync
# Finder 환경설정과 무관하게 배경 파일을 완전히 숨김.
chflags hidden "$MNT/.bg.png" 2>/dev/null || true
# detach: Finder 핸들이 남아 convert 가 실패하지 않게 끈질기게 정리.
# 자동 번호 변종("Install CatClock 1" 등)까지 함께 강제 분리.
sleep 1
shopt -s nullglob
for try in 1 2 3 4 5; do
  hdiutil detach "$MNT" -force >/dev/null 2>&1 \
    || diskutil eject "$MNT" >/dev/null 2>&1 || true
  for variant in "$MNT "*; do
    [ -d "$variant" ] || continue
    hdiutil detach "$variant" -force >/dev/null 2>&1 \
      || diskutil eject "$variant" >/dev/null 2>&1 || true
  done
  remaining=0
  [ -d "$MNT" ] && remaining=1
  for variant in "$MNT "*; do [ -d "$variant" ] && remaining=1; done
  [ "$remaining" -eq 0 ] && break
  sleep 1
done
shopt -u nullglob

# 압축 읽기전용으로 변환. 간헐 실패 대비 3회 재시도, 마지막 로그는 보여줘서 디버깅 가능하게.
CONVERT_LOG="$(mktemp)"
for attempt in 1 2 3; do
  if hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 \
       -o "$DMG" -ov >"$CONVERT_LOG" 2>&1; then
    break
  fi
  echo "  convert 실패, 재시도 ${attempt}..."
  sleep 3
done
if [ ! -f "$DMG" ]; then
  echo "✗ DMG convert 실패. 마지막 시도 로그:"
  sed 's/^/    /' "$CONVERT_LOG"
  rm -f "$CONVERT_LOG"
  exit 1
fi
rm -f "$CONVERT_LOG" "$RW_DMG"; rm -rf "$STAGE"

# --- 5. DMG 서명·공증·스테이플 ---
echo "▶︎ DMG 서명·공증·스테이플…"
codesign --force --timestamp --sign "$DEV_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo
echo "✓ 완료:"
echo "  · DMG (사람 다운로드):  $(pwd)/${DMG}"
echo "  · ZIP (Sparkle 자동업): $(pwd)/${SPARKLE_ZIP}"
echo "  · 서명 라인:             $(pwd)/${SPARKLE_SIG_OUT}"
echo "  검증: spctl -a -t open --context context:primary-signature -v \"$DMG\""
echo "  이 DMG를 사이트에 올리면 됩니다. 받는 사람은 열어서 앱을 Applications로 드래그 → 더블클릭 실행."
