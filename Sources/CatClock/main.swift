import AppKit

// 실행 타깃의 진입점. 메뉴바 상주 앱이므로 Dock 아이콘 없는 .accessory 정책.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
