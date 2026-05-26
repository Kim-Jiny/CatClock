import AppKit
import Observation

/// 시계 모드에서 표시할 지역(=시간대) 선택지. IANA 식별자를 그대로 들고
/// `TimeZone(identifier:)` 로 시간대를 얻는다. nil 선택은 디바이스 기본을 의미.
struct ClockRegion: Identifiable, Hashable {
    let id: String   // IANA tz identifier
    let name: String // 한국어 표시명
    let group: String

    /// 표시용 묶음 — 설정 메뉴 Section 분리에 사용.
    static let groups: [String] = [
        "아시아·중동", "유럽", "북미", "남미", "오세아니아", "아프리카", "기타"
    ]

    static let all: [ClockRegion] = [
        // 아시아·중동
        .init(id: "Asia/Seoul",         name: "서울",       group: "아시아·중동"),
        .init(id: "Asia/Tokyo",         name: "도쿄",       group: "아시아·중동"),
        .init(id: "Asia/Shanghai",      name: "상하이/베이징", group: "아시아·중동"),
        .init(id: "Asia/Hong_Kong",     name: "홍콩",       group: "아시아·중동"),
        .init(id: "Asia/Taipei",        name: "타이베이",   group: "아시아·중동"),
        .init(id: "Asia/Singapore",     name: "싱가포르",   group: "아시아·중동"),
        .init(id: "Asia/Bangkok",       name: "방콕",       group: "아시아·중동"),
        .init(id: "Asia/Ho_Chi_Minh",   name: "호치민",     group: "아시아·중동"),
        .init(id: "Asia/Jakarta",       name: "자카르타",   group: "아시아·중동"),
        .init(id: "Asia/Kolkata",       name: "뉴델리/뭄바이", group: "아시아·중동"),
        .init(id: "Asia/Dubai",         name: "두바이",     group: "아시아·중동"),
        // 유럽
        .init(id: "Europe/London",      name: "런던",       group: "유럽"),
        .init(id: "Europe/Paris",       name: "파리",       group: "유럽"),
        .init(id: "Europe/Berlin",      name: "베를린",     group: "유럽"),
        .init(id: "Europe/Rome",        name: "로마",       group: "유럽"),
        .init(id: "Europe/Madrid",      name: "마드리드",   group: "유럽"),
        .init(id: "Europe/Amsterdam",   name: "암스테르담", group: "유럽"),
        .init(id: "Europe/Moscow",      name: "모스크바",   group: "유럽"),
        .init(id: "Europe/Istanbul",    name: "이스탄불",   group: "유럽"),
        // 북미
        .init(id: "America/New_York",   name: "뉴욕",       group: "북미"),
        .init(id: "America/Chicago",    name: "시카고",     group: "북미"),
        .init(id: "America/Denver",     name: "덴버",       group: "북미"),
        .init(id: "America/Los_Angeles", name: "로스앤젤레스", group: "북미"),
        .init(id: "America/Toronto",    name: "토론토",     group: "북미"),
        .init(id: "America/Mexico_City", name: "멕시코시티", group: "북미"),
        .init(id: "Pacific/Honolulu",   name: "호놀룰루",   group: "북미"),
        // 남미
        .init(id: "America/Sao_Paulo",     name: "상파울루",       group: "남미"),
        .init(id: "America/Argentina/Buenos_Aires", name: "부에노스아이레스", group: "남미"),
        // 오세아니아
        .init(id: "Australia/Sydney",   name: "시드니",     group: "오세아니아"),
        .init(id: "Australia/Melbourne", name: "멜버른",    group: "오세아니아"),
        .init(id: "Pacific/Auckland",   name: "오클랜드",   group: "오세아니아"),
        // 아프리카
        .init(id: "Africa/Cairo",       name: "카이로",     group: "아프리카"),
        .init(id: "Africa/Johannesburg", name: "요하네스버그", group: "아프리카"),
        // 기타
        .init(id: "UTC",                name: "UTC (협정 세계시)", group: "기타"),
    ]

    static func byID(_ id: String?) -> ClockRegion? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// 현재 적용 중인 시간대의 GMT 오프셋 표시 ("UTC+9", "UTC-5:30").
    static func offsetLabel(for tz: TimeZone, at date: Date = Date()) -> String {
        let secs = tz.secondsFromGMT(for: date)
        let sign = secs >= 0 ? "+" : "-"
        let abs = Swift.abs(secs)
        let h = abs / 3600
        let m = (abs % 3600) / 60
        return m == 0
            ? "UTC\(sign)\(h)"
            : String(format: "UTC%@%d:%02d", sign, h, m)
    }
}

/// 위젯의 시계 모드용 현재 시각 발행자. 0.5초 간격 틱으로 초 경계를 빠르게 잡고,
/// `displayText` 는 `Settings.clockUse24Hour` / `Settings.clockShowSeconds`
/// / `Settings.clockShowAMPM` / `Settings.clockTimeZoneID` 에 맞춰 포맷.
@MainActor
@Observable
final class ClockEngine {
    static let shared = ClockEngine()

    private(set) var now: Date = Date()
    private var ticker: Timer?

    private init() { start() }

    func start() {
        stop()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        RunLoop.main.add(t, forMode: .common)  // 드래그 중에도 갱신
        ticker = t
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
    }

    /// 사용자가 고른 지역의 시간대. 미지정/유효하지 않으면 디바이스 기본.
    var activeTimeZone: TimeZone {
        if let id = Settings.shared.clockTimeZoneID,
           let tz = TimeZone(identifier: id) {
            return tz
        }
        return .current
    }

    /// 현재 시각을 사용자 옵션대로 포맷한 문자열.
    var displayText: String {
        let s = Settings.shared
        var cal = Calendar.current
        cal.timeZone = activeTimeZone
        let comps = cal.dateComponents([.hour, .minute, .second], from: now)
        let h24 = comps.hour ?? 0
        let m = comps.minute ?? 0
        let sec = comps.second ?? 0

        if s.clockUse24Hour {
            return s.clockShowSeconds
                ? String(format: "%02d:%02d:%02d", h24, m, sec)
                : String(format: "%02d:%02d", h24, m)
        }
        let isPM = h24 >= 12
        let h12 = (h24 % 12 == 0) ? 12 : h24 % 12
        let body = s.clockShowSeconds
            ? String(format: "%d:%02d:%02d", h12, m, sec)
            : String(format: "%d:%02d", h12, m)
        if s.clockShowAMPM {
            return "\(body) \(isPM ? "PM" : "AM")"
        }
        return body
    }
}
