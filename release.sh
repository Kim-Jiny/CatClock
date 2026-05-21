#!/bin/bash
# CatClock 원클릭 릴리즈 스크립트.
#
# 사용:
#   ./release.sh <버전>                  → 노트 자동 생성(이전 태그~현재 커밋)
#   ./release.sh <버전> --notes "..."    → 노트 직접 지정
#   ./release.sh <버전> --draft          → GitHub Release 를 draft 로
#
# 동작:
#   1) Info.plist 의 CFBundleShortVersionString 을 <버전>으로 설정, BundleVersion +1
#   2) 변경사항 커밋·푸시 (작업 트리는 미리 깨끗해야 함)
#   3) release_dmg.sh 로 서명·공증·DMG·ZIP·EdDSA 서명 빌드
#   4) <버전> annotated 태그 생성·푸시
#   5) gh release create 로 GitHub Release + DMG 첨부
#   6) JinyShop 디렉토리에 DMG/ZIP 복사 + appcast.xml 새 <item> prepend (Sparkle 자동 업데이트)
#      → 사용자는 JinyShop 변경사항을 확인 후 직접 git push 해야 한다 (자동 push 안 함)
set -euo pipefail
cd "$(dirname "$0")"

JINYSHOP_DIR="${JINYSHOP_DIR:-$HOME/Documents/Jiny/JinyShop}"
JINYSHOP_REL_PATH="projects/cat-clock"
JINYSHOP_DEST="${JINYSHOP_DIR}/${JINYSHOP_REL_PATH}"
APPCAST="${JINYSHOP_DEST}/appcast.xml"
BASE_URL="https://jiny.shop/${JINYSHOP_REL_PATH}"

# --- 인자 ---
VERSION="${1:-}"
[ -z "$VERSION" ] && { echo "사용: ./release.sh <버전> [--notes \"...\"] [--draft]"; exit 1; }
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || { echo "✗ 버전은 X.Y.Z 형식이어야 함 (예: 1.0.1)"; exit 1; }
shift
NOTES=""
DRAFT_FLAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --notes) NOTES="$2"; shift 2;;
    --draft) DRAFT_FLAG="--draft"; shift;;
    *) echo "알 수 없는 옵션: $1"; exit 1;;
  esac
done

# --- 사전 점검 ---
echo "▶︎ 사전 점검…"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "✗ git 저장소가 아님"; exit 1; }
if [ -n "$(git status --porcelain)" ]; then
  echo "✗ 커밋 안 된 변경사항이 있음. 먼저 정리해주세요:"
  git status --short
  exit 1
fi
git tag -l | grep -qx "$VERSION" \
  && { echo "✗ 태그 '$VERSION' 가 이미 존재함"; exit 1; }
command -v gh >/dev/null \
  || { echo "✗ gh(GitHub CLI) 가 필요합니다"; exit 1; }

PLIST="Resources/Info.plist"
PB=/usr/libexec/PlistBuddy

# --- 1) Info.plist 버전 갱신 ---
OLD_BUILD="$($PB -c "Print CFBundleVersion" "$PLIST")"
NEW_BUILD=$((OLD_BUILD + 1))
$PB -c "Set CFBundleShortVersionString $VERSION" "$PLIST"
$PB -c "Set CFBundleVersion $NEW_BUILD" "$PLIST"
echo "▶︎ Info.plist: $VERSION (build $NEW_BUILD)"

# --- 2) 커밋·푸시 ---
git add "$PLIST"
git commit -m "Release $VERSION (build $NEW_BUILD)" >/dev/null
git push >/dev/null
echo "▶︎ 버전 커밋·푸시 완료"

# --- 3) DMG/ZIP 빌드 (서명·공증 포함, 수 분 소요) ---
echo "▶︎ DMG/ZIP 빌드 시작…"
./release_dmg.sh
[ -f CatClock.dmg ] || { echo "✗ CatClock.dmg 가 생성되지 않음"; exit 1; }
[ -f CatClock.zip ] || { echo "✗ CatClock.zip 가 생성되지 않음"; exit 1; }
[ -f CatClock-sparkle.sig ] || { echo "✗ Sparkle 서명 파일이 생성되지 않음"; exit 1; }

# --- 4) 태그 생성·푸시 ---
git tag -a "$VERSION" -m "CatClock $VERSION"
git push origin "$VERSION"
echo "▶︎ 태그 $VERSION 푸시"

# --- 5) GitHub Release 생성 + DMG 첨부 ---
if [ -n "$NOTES" ]; then
  gh release create "$VERSION" CatClock.dmg \
    --title "CatClock $VERSION" \
    --notes "$NOTES" \
    $DRAFT_FLAG
else
  gh release create "$VERSION" CatClock.dmg \
    --title "CatClock $VERSION" \
    --generate-notes \
    $DRAFT_FLAG
fi

# --- 6) JinyShop 자산·appcast 갱신 ---
echo "▶︎ JinyShop 갱신 ($JINYSHOP_DEST)…"
[ -d "$JINYSHOP_DEST" ] || { echo "✗ JinyShop 디렉토리 없음: $JINYSHOP_DEST"; exit 1; }
[ -f "$APPCAST" ] || { echo "✗ appcast.xml 없음: $APPCAST (먼저 템플릿을 만들어두세요)"; exit 1; }

DMG_VER="${JINYSHOP_DEST}/CatClock-${VERSION}.dmg"
ZIP_VER="${JINYSHOP_DEST}/CatClock-${VERSION}.zip"
cp CatClock.dmg "$DMG_VER"
cp CatClock.zip "$ZIP_VER"
echo "  복사: $DMG_VER"
echo "  복사: $ZIP_VER"

# appcast.xml 에 새 <item> 끼워넣기.
# 템플릿 안 sentinel 주석 "<!-- AUTO-INSERT-BELOW -->" 바로 아래에 prepend.
SIG_LINE="$(cat CatClock-sparkle.sig)"
PUB_DATE="$(LC_ALL=en_US.UTF-8 date -R 2>/dev/null || LC_ALL=en_US.UTF-8 date '+%a, %d %b %Y %H:%M:%S %z')"
ZIP_LEN="$(stat -f%z "$ZIP_VER")"
RELEASE_NOTES_URL="${BASE_URL}/releases/v${VERSION}/"
ZIP_URL="${BASE_URL}/CatClock-${VERSION}.zip"

ITEM="    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${NEW_BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>${RELEASE_NOTES_URL}</sparkle:releaseNotesLink>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure url=\"${ZIP_URL}\" length=\"${ZIP_LEN}\" type=\"application/octet-stream\" ${SIG_LINE} />
    </item>"

# sentinel 라인 바로 아래에 ITEM 삽입. awk 로 in-place 치환.
TMP_APPCAST="$(mktemp)"
awk -v item="$ITEM" '
  /<!-- AUTO-INSERT-BELOW -->/ { print; print item; next }
  { print }
' "$APPCAST" > "$TMP_APPCAST"
if ! grep -q "<title>Version ${VERSION}</title>" "$TMP_APPCAST"; then
  echo "✗ appcast 에 새 item 이 삽입되지 않음. sentinel '<!-- AUTO-INSERT-BELOW -->' 가 파일에 있는지 확인하세요."
  rm "$TMP_APPCAST"
  exit 1
fi
mv "$TMP_APPCAST" "$APPCAST"
echo "  appcast 갱신: $APPCAST"

echo
echo "✓ 릴리즈 완료: https://github.com/Kim-Jiny/CatClock/releases/tag/$VERSION"
echo
echo "▶︎ 다음 단계 — JinyShop 변경사항 확인 후 push 해주세요:"
echo "    cd \"$JINYSHOP_DIR\""
echo "    git status"
echo "    git add ${JINYSHOP_REL_PATH}/"
echo "    git commit -m \"CatClock ${VERSION}\""
echo "    git push"
echo
echo "  push 가 끝나면 https://jiny.shop 에 배포되어 자동 업데이트가 활성화됩니다."
