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
#   3) release_dmg.sh 로 서명·공증·DMG 빌드
#   4) <버전> annotated 태그 생성·푸시
#   5) gh release create 로 GitHub Release + DMG 첨부
set -euo pipefail
cd "$(dirname "$0")"

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

# --- 3) DMG 빌드 (서명·공증 포함, 수 분 소요) ---
echo "▶︎ DMG 빌드 시작…"
./release_dmg.sh
[ -f CatClock.dmg ] || { echo "✗ CatClock.dmg 가 생성되지 않음"; exit 1; }

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

echo
echo "✓ 릴리즈 완료: https://github.com/Kim-Jiny/CatClock/releases/tag/$VERSION"
