import AppKit
import SwiftUI

/// UserDefaults 보관용 Color ↔ "#RRGGBB(AA)" 변환.
extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var n: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&n) else { return nil }
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((n >> 24) & 0xff) / 255
            g = Double((n >> 16) & 0xff) / 255
            b = Double((n >> 8)  & 0xff) / 255
            a = Double( n        & 0xff) / 255
        } else {
            r = Double((n >> 16) & 0xff) / 255
            g = Double((n >> 8)  & 0xff) / 255
            b = Double( n        & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        let a = Int((ns.alphaComponent * 255).rounded())
        return a < 255
            ? String(format: "#%02X%02X%02X%02X", r, g, b, a)
            : String(format: "#%02X%02X%02X", r, g, b)
    }
}

/// 타이머 숫자 글씨체.
enum TimerFontStyle: String, CaseIterable, Identifiable {
    case rounded       // SF Rounded (기본)
    case monospaced    // SF Mono — 디지털 시계
    case standard      // SF Pro
    case serif         // New York
    case typewriter    // American Typewriter — 레트로
    case chalkboard    // Chalkboard SE — 캐주얼
    case marker        // Marker Felt — 손글씨 굵게
    case handwriting   // Snell Roundhand — 우아한 필기

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rounded:     return "둥글둥글"
        case .monospaced:  return "디지털"
        case .standard:    return "시스템"
        case .serif:       return "세리프"
        case .typewriter:  return "타자기"
        case .chalkboard:  return "칠판"
        case .marker:      return "마커"
        case .handwriting: return "필기체"
        }
    }

    /// 미리보기·실제 렌더링 공용 폰트. weight 는 호출처에서 지정.
    func font(size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        switch self {
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .monospaced:
            return .system(size: size, weight: weight, design: .monospaced)
        case .standard:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .typewriter:
            // .custom 은 weight 적용이 잘 안 먹어 굵은 변형을 직접 지정.
            return .custom("AmericanTypewriter-Bold", size: size)
        case .chalkboard:
            return .custom("ChalkboardSE-Bold", size: size)
        case .marker:
            return .custom("MarkerFelt-Wide", size: size)
        case .handwriting:
            return .custom("SnellRoundhand-Black", size: size)
        }
    }
}

/// 위젯·메뉴바의 시간 표시 형식.
enum TimerDisplayFormat: String, CaseIterable, Identifiable {
    case auto             // 25:30 / 1:25:30
    case noSeconds        // H:MM (초 생략, 분 단위 올림)
    case minutesWithUnit  // 345m
    case secondsWithUnit  // 34890s
    case korean           // 1시간 25분 30초

    var id: String { rawValue }

    /// 설정창 Picker 에 보일 라벨 (예시 포함).
    var title: String {
        switch self {
        case .auto:             return "자동 (1:10:10)"
        case .noSeconds:        return "초 없음 (1:10)"
        case .minutesWithUnit:  return "분 단위 (345m)"
        case .secondsWithUnit:  return "초 단위 (34890s)"
        case .korean:           return "한글 (1시간 25분 30초)"
        }
    }

    /// 남은 초를 이 형식의 표시 문자열로 변환.
    func format(seconds: Int) -> String {
        let secs = max(0, seconds)
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        switch self {
        case .auto:
            return h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)
        case .noSeconds:
            // 30초 이상이면 다음 분으로 올림 → H:MM.
            let mTotal = (secs + 30) / 60
            return String(format: "%d:%02d", mTotal / 60, mTotal % 60)
        case .minutesWithUnit:
            return "\((secs + 30) / 60)m"
        case .secondsWithUnit:
            return "\(secs)s"
        case .korean:
            var parts: [String] = []
            if h > 0 { parts.append("\(h)시간") }
            if m > 0 { parts.append("\(m)분") }
            if s > 0 || parts.isEmpty { parts.append("\(s)초") }
            return parts.joined(separator: " ")
        }
    }
}

/// UserDefaults 기반 설정 저장소. @Observable 이라 SwiftUI 가 view 의 의존성을
/// 자동 추적해 옵션 변경 즉시 redraw.
@Observable
@MainActor
final class Settings {
    static let shared = Settings()

    @ObservationIgnored private let defaults = UserDefaults.standard

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
        static let timerDisplayFormat = "timerDisplayFormat"
        static let timerFontStyle = "timerFontStyle"
        static let timerFillColorHex = "timerFillColorHex"
        static let timerStrokeColorHex = "timerStrokeColorHex"
        static let timerShowOutline = "timerShowOutline"
    }

    var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }
    var isWidgetVisible: Bool {
        didSet { defaults.set(isWidgetVisible, forKey: Key.isWidgetVisible) }
    }
    /// 실행되면 자동으로 타이머 시작 (로그인 자동실행과 조합 시 출퇴근용으로 유용).
    var autoStartOnLaunch: Bool {
        didSet { defaults.set(autoStartOnLaunch, forKey: Key.autoStartOnLaunch) }
    }
    /// 위젯 크기 배율 (0이면 미설정 → 1.0으로 간주).
    var widgetScale: Double {
        didSet { defaults.set(widgetScale, forKey: Key.widgetScale) }
    }
    /// 위젯 내 시간 숫자의 위치(0~1 정규화). 미설정 시 nil → 기본 하단 중앙.
    var timerPos: CGPoint? {
        didSet {
            guard let p = timerPos else { return }
            defaults.set(p.x, forKey: Key.timerPosX)
            defaults.set(p.y, forKey: Key.timerPosY)
            defaults.set(true, forKey: Key.hasTimerPos)
        }
    }
    /// 시간 글자 크기. 0이면 미설정 → 기본값.
    var timerFontSize: Double {
        didSet { defaults.set(timerFontSize, forKey: Key.timerFontSize) }
    }
    /// 카운트(시간 숫자)를 마우스 호버 시에만 표시.
    var hideCountUnlessHover: Bool {
        didSet { defaults.set(hideCountUnlessHover, forKey: Key.hideCountUnlessHover) }
    }
    /// 타이머 완료(및 4초 반복 알람) 시 소리(NSSound.beep) 재생.
    var soundOnFinish: Bool {
        didSet { defaults.set(soundOnFinish, forKey: Key.soundOnFinish) }
    }
    /// 위젯·메뉴바의 시간 표시 형식.
    var timerDisplayFormat: TimerDisplayFormat {
        didSet { defaults.set(timerDisplayFormat.rawValue, forKey: Key.timerDisplayFormat) }
    }
    /// 타이머 숫자 글씨체.
    var timerFontStyle: TimerFontStyle {
        didSet { defaults.set(timerFontStyle.rawValue, forKey: Key.timerFontStyle) }
    }
    /// 타이머 글씨 채움색. paused 노랑·done 빨강은 상태 강조용으로 유지하고,
    /// running/idle 에서만 이 색이 적용된다.
    var timerFillColor: Color {
        didSet { defaults.set(timerFillColor.hexString, forKey: Key.timerFillColorHex) }
    }
    /// 타이머 외곽선 색.
    var timerStrokeColor: Color {
        didSet { defaults.set(timerStrokeColor.hexString, forKey: Key.timerStrokeColorHex) }
    }
    /// 타이머 외곽선 표시 여부 (boxed 스킨에는 영향 없음 — 거기 글씨는 원래 외곽선 없음).
    var timerShowOutline: Bool {
        didSet { defaults.set(timerShowOutline, forKey: Key.timerShowOutline) }
    }
    /// 사용자가 넣은 고양이 사진 파일명(앱 지원 폴더 내).
    var customCatFileName: String? {
        didSet { defaults.set(customCatFileName, forKey: Key.customCatFileName) }
    }
    /// 선택한 고양이 스킨 id.
    var catSkinID: String? {
        didSet { defaults.set(catSkinID, forKey: Key.catSkinID) }
    }
    /// 마지막으로 쓴 타이머 모드/설정값.
    var timerMode: TimerMode? {
        didSet {
            guard let v = timerMode, let data = try? JSONEncoder().encode(v) else { return }
            defaults.set(data, forKey: Key.timerMode)
        }
    }
    /// 저장된 위젯 좌하단 좌표. 한 번도 옮긴 적 없으면 nil.
    var widgetOrigin: NSPoint? {
        didSet {
            guard let p = widgetOrigin else { return }
            defaults.set(p.x, forKey: Key.widgetOriginX)
            defaults.set(p.y, forKey: Key.widgetOriginY)
            defaults.set(true, forKey: Key.hasSavedOrigin)
        }
    }

    private init() {
        defaults.register(defaults: [
            Key.isWidgetVisible: true,
            Key.soundOnFinish: true,
            Key.timerShowOutline: true
        ])

        displayMode = DisplayMode(rawValue: defaults.string(forKey: Key.displayMode) ?? "") ?? .alwaysOnTop
        isWidgetVisible = defaults.bool(forKey: Key.isWidgetVisible)
        autoStartOnLaunch = defaults.bool(forKey: Key.autoStartOnLaunch)
        widgetScale = defaults.double(forKey: Key.widgetScale)
        timerPos = defaults.bool(forKey: Key.hasTimerPos)
            ? CGPoint(x: defaults.double(forKey: Key.timerPosX),
                      y: defaults.double(forKey: Key.timerPosY))
            : nil
        timerFontSize = defaults.double(forKey: Key.timerFontSize)
        hideCountUnlessHover = defaults.bool(forKey: Key.hideCountUnlessHover)
        soundOnFinish = defaults.bool(forKey: Key.soundOnFinish)
        timerDisplayFormat = TimerDisplayFormat(rawValue: defaults.string(forKey: Key.timerDisplayFormat) ?? "") ?? .auto
        timerFontStyle = TimerFontStyle(rawValue: defaults.string(forKey: Key.timerFontStyle) ?? "") ?? .rounded
        timerFillColor = Color(hexString: defaults.string(forKey: Key.timerFillColorHex) ?? "") ?? .white
        timerStrokeColor = Color(hexString: defaults.string(forKey: Key.timerStrokeColorHex) ?? "") ?? .black
        timerShowOutline = defaults.bool(forKey: Key.timerShowOutline)
        customCatFileName = defaults.string(forKey: Key.customCatFileName)
        catSkinID = defaults.string(forKey: Key.catSkinID)
        timerMode = (defaults.data(forKey: Key.timerMode))
            .flatMap { try? JSONDecoder().decode(TimerMode.self, from: $0) }
        widgetOrigin = defaults.bool(forKey: Key.hasSavedOrigin)
            ? NSPoint(x: defaults.double(forKey: Key.widgetOriginX),
                      y: defaults.double(forKey: Key.widgetOriginY))
            : nil
    }
}
