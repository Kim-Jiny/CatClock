import AppKit
import Sparkle

@MainActor
final class UpdaterController {
    static let shared = UpdaterController()

    let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    // LSUIElement 앱이라 평소엔 비활성 상태 → 모달이 뒤에 깔리는 걸 막기 위해
    // 사용자가 체크를 트리거할 때 명시적으로 앱을 활성화한다.
    func checkForUpdates(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(sender)
    }
}
