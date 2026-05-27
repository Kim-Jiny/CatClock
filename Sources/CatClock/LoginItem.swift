import Foundation
import ServiceManagement

/// 로그인 시 자동 실행. `SMAppService.mainApp` 를 사용.
///
/// - MAS(샌드박스) 빌드: 필수 경로. LaunchAgent plist 직접 쓰기는 샌드박스에서 차단됨.
/// - 직접배포 빌드: Developer ID 서명 + 공증된 .app 이 /Applications 에 있으면 정상 동작.
///   ad-hoc 서명(`build_app.sh` 로컬 개발용) 에서는 EINVAL 가 날 수 있으므로 `set` 이
///   false 를 리턴하면 UI 에서 안내한다.
enum LoginItem {

    /// 정식 .app 번들로 실행 중일 때만 의미 있음.
    /// DMG에서 직접 실행 중일 때(`/Volumes/...`)는 마운트 해제 시 경로가 사라지므로 제외.
    static var isSupported: Bool {
        let path = Bundle.main.bundlePath
        return path.hasSuffix(".app") && !path.hasPrefix("/Volumes/")
    }

    /// 현재 로그인 항목이 등록돼 있는지.
    static var isEnabled: Bool {
        guard isSupported else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        guard isSupported else {
            NSLog("LoginItem: .app 번들이 아니라 등록 불가 (개발 실행)")
            return false
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("LoginItem 변경 실패: \(error.localizedDescription)")
            return false
        }
    }
}
