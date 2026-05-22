import AppKit
import Observation

/// 타이머 모드. 작업 타이머(분 단위) / 퇴근 타이머(목표 시각).
enum TimerMode: Codable, Equatable {
    /// 집중용: N분 동안 집중.
    case task(minutes: Int)
    /// 출퇴근용: 오늘 hour:minute 까지 카운트다운.
    case workOff(hour: Int, minute: Int)
    /// 출퇴근용: 시작 시점부터 근무 N시간 M분 후 퇴근.
    case workDuration(hours: Int, minutes: Int)

    var label: String {
        switch self {
        case .task: return "집중 타이머"
        case .workOff, .workDuration: return "퇴근 타이머"
        }
    }
}

enum TimerState {
    case idle      // 설정만 됨, 시작 전
    case running
    case paused
    case done      // 0 도달
}

/// 타이머 핵심 로직. 정확도를 위해 "목표 시각(endDate)" 기준으로 남은 시간을 계산한다.
/// 1초 틱은 화면 갱신용일 뿐, 누적 오차가 쌓이지 않는다.
@MainActor
@Observable
final class TimerEngine {
    static let shared = TimerEngine()

    private(set) var state: TimerState = .idle
    private(set) var remaining: TimeInterval = 0
    private(set) var total: TimeInterval = 0
    /// 종료 후 아직 끄지 않아 알림이 울리는 중.
    private(set) var isAlerting = false

    var mode: TimerMode {
        didSet {
            Settings.shared.timerMode = mode
            if state == .idle || state == .done { resetToConfigured() }
        }
    }

    private var endDate: Date?
    private var ticker: Timer?
    private var alertTicker: Timer?

    /// 타이머가 0에 도달한 순간 1회 호출(위젯을 앞으로 끌어오는 용도).
    var onFinished: (() -> Void)?

    private init() {
        self.mode = Settings.shared.timerMode ?? .task(minutes: 25)
        resetToConfigured()
    }

    // MARK: - 표시

    /// 사용자가 고른 형식대로 남은 시간 텍스트 반환.
    var displayText: String {
        Settings.shared.timerDisplayFormat.format(seconds: Int(remaining.rounded()))
    }

    /// 위젯 하단 부제. 모드/상태 한 줄 설명.
    var subtitle: String {
        if state == .done {
            switch mode {
            case .task:                  return "끝났어요!"
            case .workOff, .workDuration: return "퇴근! 🎉"
            }
        }
        switch mode {
        case .task(let m):
            return "집중 · \(m)분"
        case .workOff(let h, let mm):
            return String(format: "퇴근 %02d:%02d", h, mm)
        case .workDuration(let h, let mm):
            return mm > 0 ? "근무 \(h)시간 \(mm)분" : "근무 \(h)시간"
        }
    }

    var progress: Double {
        total > 0 ? max(0, min(1, 1 - remaining / total)) : 0
    }

    // MARK: - 제어

    func start() {
        guard state == .idle || state == .done else { return }
        let duration = plannedDuration()
        guard duration > 0 else { return }
        total = duration
        endDate = Date().addingTimeInterval(duration)
        state = .running
        startTicker()
        tick()
    }

    func pause() {
        guard state == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        endDate = nil
        stopTicker()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        startTicker()
        tick()
    }

    func toggle() {
        switch state {
        case .idle, .done: start()
        case .running:     pause()
        case .paused:      resume()
        }
    }

    func reset() {
        stopTicker()
        stopAlert()
        endDate = nil
        state = .idle
        resetToConfigured()
    }

    /// 종료 알림만 끄고 done 상태는 유지(끄기 버튼용).
    func acknowledge() {
        stopAlert()
    }

    // MARK: - 내부

    /// 현재 모드 기준 시작 시 걸릴 시간(초).
    private func plannedDuration() -> TimeInterval {
        switch mode {
        case .task(let minutes):
            return TimeInterval(max(1, minutes) * 60)
        case .workOff(let hour, let minute):
            return secondsUntil(hour: hour, minute: minute)
        case .workDuration(let hours, let minutes):
            return TimeInterval(max(1, hours * 3600 + minutes * 60))
        }
    }

    /// idle 상태에서 보여줄 남은 시간 미리 채우기.
    private func resetToConfigured() {
        let d = plannedDuration()
        total = d
        remaining = d
    }

    /// 오늘 hour:minute 까지 남은 초. 이미 지났으면 내일 같은 시각.
    private func secondsUntil(hour: Int, minute: Int) -> TimeInterval {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        guard var target = cal.date(from: comps) else { return 0 }
        if target <= now {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target.timeIntervalSince(now)
    }

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)  // 드래그 중에도 갱신
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard state == .running, let end = endDate else { return }
        let left = end.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            finish()
        } else {
            remaining = left
        }
    }

    private func finish() {
        stopTicker()
        endDate = nil
        state = .done
        isAlerting = true
        if Settings.shared.soundOnFinish { NSSound.beep() }
        onFinished?()
        // 끌 때까지 4초마다 다시 울림 (사용자가 비프 옵션 끄면 시각 알림만 유지).
        let t = Timer(timeInterval: 4, repeats: true) { _ in
            Task { @MainActor in
                if Settings.shared.soundOnFinish { NSSound.beep() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        alertTicker = t
    }

    private func stopAlert() {
        alertTicker?.invalidate()
        alertTicker = nil
        isAlerting = false
    }
}
