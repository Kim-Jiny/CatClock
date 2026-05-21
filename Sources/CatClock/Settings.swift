import AppKit

/// UserDefaults 기반 설정 저장소. 창 위치·표시 모드·표시 여부를 기억한다.
@MainActor
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let displayMode = "displayMode"
        static let widgetOriginX = "widgetOriginX"
        static let widgetOriginY = "widgetOriginY"
        static let isWidgetVisible = "isWidgetVisible"
        static let hasSavedOrigin = "hasSavedOrigin"
        static let timerMode = "timerMode"
        static let catSkinID = "catSkinID"
        static let autoStartOnLaunch = "autoStartOnLaunch"
        static let customCatFileName = "customCatFileName"
        static let widgetScale = "widgetScale"
        static let timerPosX = "timerPosX"
        static let timerPosY = "timerPosY"
        static let timerFontSize = "timerFontSize"
        static let hasTimerPos = "hasTimerPos"
        static let hideCountUnlessHover = "hideCountUnlessHover"
        static let soundOnFinish = "soundOnFinish"
    }

    private init() {
        defaults.register(defaults: [
            Key.isWidgetVisible: true,
            Key.soundOnFinish: true
        ])
    }

    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: defaults.string(forKey: Key.displayMode) ?? "") ?? .alwaysOnTop }
        set { defaults.set(newValue.rawValue, forKey: Key.displayMode) }
    }

    var isWidgetVisible: Bool {
        get { defaults.bool(forKey: Key.isWidgetVisible) }
        set { defaults.set(newValue, forKey: Key.isWidgetVisible) }
    }

    /// 실행되면 자동으로 타이머 시작 (로그인 자동실행과 조합 시 출퇴근용으로 유용).
    var autoStartOnLaunch: Bool {
        get { defaults.bool(forKey: Key.autoStartOnLaunch) }
        set { defaults.set(newValue, forKey: Key.autoStartOnLaunch) }
    }

    /// 위젯 크기 배율 (0이면 미설정 → 1.0으로 간주).
    var widgetScale: Double {
        get { defaults.double(forKey: Key.widgetScale) }
        set { defaults.set(newValue, forKey: Key.widgetScale) }
    }

    /// 위젯 내 시간 숫자의 위치(0~1 정규화). 미설정 시 nil → 기본 하단 중앙.
    var timerPos: CGPoint? {
        get {
            guard defaults.bool(forKey: Key.hasTimerPos) else { return nil }
            return CGPoint(x: defaults.double(forKey: Key.timerPosX),
                           y: defaults.double(forKey: Key.timerPosY))
        }
        set {
            guard let p = newValue else { return }
            defaults.set(p.x, forKey: Key.timerPosX)
            defaults.set(p.y, forKey: Key.timerPosY)
            defaults.set(true, forKey: Key.hasTimerPos)
        }
    }

    /// 시간 글자 크기. 0이면 미설정 → 기본값.
    var timerFontSize: Double {
        get { defaults.double(forKey: Key.timerFontSize) }
        set { defaults.set(newValue, forKey: Key.timerFontSize) }
    }

    /// 카운트(시간 숫자)를 마우스 호버 시에만 표시.
    var hideCountUnlessHover: Bool {
        get { defaults.bool(forKey: Key.hideCountUnlessHover) }
        set { defaults.set(newValue, forKey: Key.hideCountUnlessHover) }
    }

    /// 타이머 완료(및 4초 반복 알람) 시 소리(NSSound.beep) 재생.
    var soundOnFinish: Bool {
        get { defaults.bool(forKey: Key.soundOnFinish) }
        set { defaults.set(newValue, forKey: Key.soundOnFinish) }
    }

    /// 사용자가 넣은 고양이 사진 파일명(앱 지원 폴더 내).
    var customCatFileName: String? {
        get { defaults.string(forKey: Key.customCatFileName) }
        set { defaults.set(newValue, forKey: Key.customCatFileName) }
    }

    /// 선택한 고양이 스킨 id.
    var catSkinID: String? {
        get { defaults.string(forKey: Key.catSkinID) }
        set { defaults.set(newValue, forKey: Key.catSkinID) }
    }

    /// 마지막으로 쓴 타이머 모드/설정값.
    var timerMode: TimerMode? {
        get {
            guard let data = defaults.data(forKey: Key.timerMode) else { return nil }
            return try? JSONDecoder().decode(TimerMode.self, from: data)
        }
        set {
            guard let v = newValue, let data = try? JSONEncoder().encode(v) else { return }
            defaults.set(data, forKey: Key.timerMode)
        }
    }

    /// 저장된 위젯 좌하단 좌표. 한 번도 옮긴 적 없으면 nil.
    var widgetOrigin: NSPoint? {
        get {
            guard defaults.bool(forKey: Key.hasSavedOrigin) else { return nil }
            return NSPoint(x: defaults.double(forKey: Key.widgetOriginX),
                           y: defaults.double(forKey: Key.widgetOriginY))
        }
        set {
            guard let p = newValue else { return }
            defaults.set(p.x, forKey: Key.widgetOriginX)
            defaults.set(p.y, forKey: Key.widgetOriginY)
            defaults.set(true, forKey: Key.hasSavedOrigin)
        }
    }
}
