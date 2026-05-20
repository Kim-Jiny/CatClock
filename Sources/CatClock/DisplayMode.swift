import AppKit

/// 위젯 표시 모드. 기획서의 "최상단 고정 ↔ 데스크탑에만"에 대응.
enum DisplayMode: String, CaseIterable {
    /// 다른 앱 위에 항상 보임.
    case alwaysOnTop
    /// 바탕화면 레벨. 다른 앱을 켜면 가려짐.
    case desktopOnly

    var title: String {
        switch self {
        case .alwaysOnTop: return "최상단 고정"
        case .desktopOnly: return "데스크탑에만"
        }
    }

    /// 모드에 해당하는 NSWindow 레벨.
    var windowLevel: NSWindow.Level {
        switch self {
        case .alwaysOnTop:
            return .floating
        case .desktopOnly:
            // 바탕화면 아이콘 바로 위 레벨.
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        }
    }
}
