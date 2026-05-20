# CatClock

맥용 고양이 플로팅 타이머 위젯. 기획은 [`기획.md`](기획.md) 참고.

## 개발 상태
- [x] 0단계: 프로젝트 스캐폴드 (메뉴바 상주 앱)
- [x] 1단계: 투명 플로팅 패널 — 드래그 이동, 위치 기억, 표시 모드(최상단/데스크탑) 전환
- [x] 3단계: 타이머 코어 — 작업 타이머(분), 시작/일시정지/리셋, 진행 막대, 종료 비프
- [x] 4단계: 퇴근 타이머 — 목표 시각 카운트다운 (지난 시각이면 다음 날)
- [x] 5단계: 고양이 그래픽 (SF Symbols 합성, 상태별 표정/동작)
- [x] 6단계: 고양이 종류 선택 (스킨 6종, 설정에서 미리보기 선택·저장)
- [x] 7단계: 알림 강화 — 끌 때까지 4초마다 반복 비프, 종료 시 위젯 자동 등장+빨강 깜빡, "끄기" 버튼
- [x] 8단계: 메뉴바 다듬기 — 상태/카운트다운 표시, 시작/일시정지/리셋·끄기 메뉴, 위젯 부제(모드 표시)
- [x] .app 번들화 + 로그인 자동 실행 + 실행 시 자동 시작 + 근무시간(N시간) 모드
- [x] 내 고양이 사진 넣기 — 사진 가득 채움, 시간은 테두리 글씨로 아래쪽에 겹침(배경·부제 없음)
- [x] 위젯이 화면 밖이면 자동으로 화면 안으로 복원(좌표 보정)
- [ ] 추후: 타이머 여러 개 / 프리셋 / 기본 스킨 실제 그림 교체

## 실행

터미널에서:

```bash
swift run
```

또는 Xcode에서 `Package.swift`를 열고 ▶︎ 실행.

실행하면 Dock 아이콘 없이 **메뉴바에 고양이 아이콘**이 생기고,
화면 우상단에 위젯이 뜹니다. 위젯을 끌어서 옮길 수 있고,
메뉴바 아이콘에서 표시/숨김·표시 모드 전환·종료가 가능합니다.

종료: 메뉴바 아이콘 → "CatClock 종료" (또는 터미널에서 Ctrl+C).

## 실제로 쓸 때 (.app 만들기)

평소 개발은 `swift run`. **실제로 쓸 버전을 굳힐 때만** 아래 한 줄:

```bash
./build_app.sh            # ./CatClock.app 생성·갱신
./build_app.sh --install  # 위 + /Applications 에 설치
```

즉 "고치다가 → 만족스러우면 스크립트 1회". 업데이트 = 스크립트 다시 실행.

### 출퇴근용 자동화
설정(메뉴바 → 타이머 설정…)에서:
1. **출퇴근용 → 근무 시간**에 예: `9시간` 설정
2. **로그인 시 CatClock 자동 실행** 체크 (~/Library/LaunchAgents 에 LaunchAgent 등록)
3. **실행되면 자동으로 타이머 시작** 체크

→ 아침에 로그인하면 CatClock이 켜지고 9시간 카운트다운이 자동 시작, 퇴근 시각에 "퇴근! 🎉" 반복 알림.
> 로그인 자동 실행은 정식 `.app`(build_app.sh)으로 실행해야 적용됩니다. `swift run`에선 무시됨.
> `.app` 위치를 옮기면 토글을 한 번 껐다 켜서 경로를 갱신하세요.

## 구조
| 파일 | 역할 |
|---|---|
| `main.swift` | 진입점, .accessory 정책 |
| `AppDelegate.swift` | 메뉴바·패널 구성, 액션 |
| `FloatingPanel.swift` | 투명·드래그·레벨 전환 패널 |
| `WidgetView.swift` | 위젯 UI (시간·진행·컨트롤) |
| `TimerEngine.swift` | 타이머 핵심 로직 (목표 시각 기준) |
| `SettingsView.swift` | 모드/값/고양이 종류 설정 화면 |
| `CatSkin.swift` / `SkinStore.swift` | 고양이 스킨 6종 + 선택 저장 |
| `CustomCat.swift` | 사용자 사진 보관/로드 (앱 지원 폴더) |
| `CatView.swift` | 고양이+알람시계 SF Symbols 합성 뷰 |
| `LoginItem.swift` | 로그인 자동 실행 (LaunchAgent plist) |
| `DisplayMode.swift` | 최상단/데스크탑 모드 |
| `Settings.swift` | UserDefaults 저장 |
| `build_app.sh` / `Resources/Info.plist` | .app 번들 빌드 스크립트 |

> Swift 6 strict concurrency 사용 — UI 타입은 `@MainActor` 격리 필요.
