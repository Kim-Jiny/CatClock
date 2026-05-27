import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private let menu = NSMenu()
    private let store = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !APPSTORE
        // Sparkle 업데이터 초기화: startingUpdater=true 라 시동 시 + 24시간 주기 자동 체크 시작.
        // MAS 빌드는 스토어가 업데이트를 처리하므로 초기화하지 않는다.
        _ = UpdaterController.shared
        #endif
        setupPanel()
        setupMenuBar()

        // 로그인 자동 실행 등과 조합: 켜져 있으면 바로 타이머 시작.
        if store.autoStartOnLaunch {
            store.isWidgetVisible = true
            panel.orderFrontRegardless()
            TimerEngine.shared.start()
            rebuildMenu()
        }
    }

    // MARK: - 플로팅 패널

    private func setupPanel() {
        panel = FloatingPanel(displayMode: store.displayMode)
        panel.contentView = NSHostingView(rootView: WidgetView())
        panel.applyDisplayMode(store.displayMode)
        panel.restoreFrame(savedOrigin: store.widgetOrigin)
        panel.applyScale(LayoutStore.shared.scale)
        panel.onMoved = { [weak self] origin in
            self?.store.widgetOrigin = origin
        }
        // 드래그로 크기 조절 시 패널 크기도 같이.
        LayoutStore.shared.onScaleChange = { [weak self] scale in
            self?.panel.applyScale(scale)
            self?.store.widgetOrigin = self?.panel.frame.origin ?? .zero
        }
        // 타이머 종료 시 위젯이 숨겨져 있어도 띄우고 앞으로 가져옴.
        TimerEngine.shared.onFinished = { [weak self] in
            guard let self else { return }
            self.store.isWidgetVisible = true
            self.panel.orderFrontRegardless()
            self.rebuildMenu()
        }
        if store.isWidgetVisible {
            panel.orderFrontRegardless()
        }
    }

    // MARK: - 메뉴바

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "CatClock")
        }
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    private func statusLine() -> String {
        let e = TimerEngine.shared
        switch e.state {
        case .idle:    return "⏹ 대기 · \(e.subtitle)"
        case .running: return "▶︎ \(e.displayText) · \(e.subtitle)"
        case .paused:  return "⏸ \(e.displayText) · \(e.subtitle)"
        case .done:    return "🔔 \(e.subtitle)"
        }
    }

    private func rebuildMenu() {
        let engine = TimerEngine.shared
        menu.removeAllItems()

        menu.addItem(withTitle: "CatClock 정보…", action: #selector(openAbout), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())

        if engine.isAlerting {
            menu.addItem(withTitle: "🔕 알림 끄기", action: #selector(ackAlert), keyEquivalent: "")
                .target = self
        }

        let toggleLabel: String
        switch engine.state {
        case .running: toggleLabel = "일시정지"
        case .paused:  toggleLabel = "계속"
        default:       toggleLabel = "시작"
        }
        menu.addItem(withTitle: toggleLabel, action: #selector(toggleTimer), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "리셋", action: #selector(resetTimer), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        menu.addItem(withTitle: "타이머 설정…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self

        menu.addItem(.separator())

        let toggleTitle = store.isWidgetVisible ? "위젯 숨기기" : "위젯 보이기"
        menu.addItem(withTitle: toggleTitle, action: #selector(toggleWidget), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        let modeHeader = NSMenuItem(title: "표시 모드", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)

        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.title,
                                  action: #selector(selectDisplayMode(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (mode == store.displayMode) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "CatClock 종료", action: #selector(quit), keyEquivalent: "q")
            .target = self
    }

    // MARK: - 액션

    @objc private func toggleWidget() {
        store.isWidgetVisible.toggle()
        if store.isWidgetVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        rebuildMenu()
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: raw) else { return }
        store.displayMode = mode
        panel.applyDisplayMode(mode)
        rebuildMenu()
    }

    @objc private func toggleTimer() {
        TimerEngine.shared.toggle()
        rebuildMenu()
    }

    @objc private func resetTimer() {
        TimerEngine.shared.reset()
        rebuildMenu()
    }

    @objc private func ackAlert() {
        TimerEngine.shared.acknowledge()
        rebuildMenu()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(onClose: { [weak self] in
                self?.settingsWindow?.close()
            })
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = "CatClock"
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.setContentSize(controller.view.fittingSize)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func checkForUpdates() {
        UpdaterController.shared.checkForUpdates(nil)
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            #if APPSTORE
            let onUpdate: (() -> Void)? = nil
            #else
            let onUpdate: (() -> Void)? = { [weak self] in self?.checkForUpdates() }
            #endif
            let view = AboutView(
                onUpdate: onUpdate,
                onClose: { [weak self] in self?.aboutWindow?.close() }
            )
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = "CatClock 정보"
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.setContentSize(controller.view.fittingSize)
            window.center()
            aboutWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    // 메뉴 열 때마다 상태/카운트다운을 최신으로 다시 그림.
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }
}
