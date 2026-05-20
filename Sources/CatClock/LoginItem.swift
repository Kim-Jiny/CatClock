import Foundation

/// 로그인 시 자동 실행. SMAppService는 ad-hoc 서명/비표준 경로에서 EINVAL이 잦아
/// 개인용으로 더 견고한 LaunchAgent(plist) 방식을 사용한다.
/// `~/Library/LaunchAgents/com.jiny.catclock.plist` 를 만들고/지운다.
enum LoginItem {

    private static let label = "com.jiny.catclock"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// 정식 .app 번들로 실행 중일 때만 의미 있음.
    /// DMG에서 직접 실행 중일 때(`/Volumes/...`)는 마운트 해제 시 경로가 사라지므로 제외.
    static var isSupported: Bool {
        let path = Bundle.main.bundlePath
        return path.hasSuffix(".app") && !path.hasPrefix("/Volumes/")
    }

    /// 현재 로그인 항목이 설치돼 있는지(plist 존재).
    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// .app 안의 실제 실행 파일 경로.
    private static var executablePath: String? {
        guard isSupported else { return nil }
        return Bundle.main.executableURL?.path
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        enabled ? install() : remove()
    }

    private static func install() -> Bool {
        guard let exec = executablePath else {
            NSLog("LoginItem: .app 번들이 아니라 등록 불가 (개발 실행)")
            return false
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exec],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        do {
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            // 이번 세션엔 bootstrap 하지 않는다 — 이미 앱이 실행 중일 때
            // RunAtLoad 가 즉시 새 인스턴스를 띄워 중복 위젯이 뜨는 문제 방지.
            // 다음 로그인에 launchd 가 자동으로 로드한다.
            return true
        } catch {
            NSLog("LoginItem 설치 실패: \(error.localizedDescription)")
            return false
        }
    }

    private static func remove() -> Bool {
        bootout()
        try? FileManager.default.removeItem(at: plistURL)
        return true
    }

    // MARK: - launchctl

    private static var domain: String { "gui/\(getuid())" }

    private static func bootout() {
        launchctl(["bootout", "\(domain)/\(label)"])
    }

    @discardableResult
    private static func launchctl(_ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardError = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }
}
