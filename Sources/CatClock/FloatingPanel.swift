import AppKit

/// 테두리 없는 투명 플로팅 패널.
/// - 다른 앱을 활성화하지 않고 떠 있음 (non-activating)
/// - 배경 어디든 잡아서 드래그 이동
/// - 표시 모드(최상단/데스크탑)에 따라 윈도우 레벨 변경
/// - 이동 시 좌표를 콜백으로 알려 위치 저장
final class FloatingPanel: NSPanel {

    /// 패널이 이동을 마쳤을 때 새 좌하단 좌표를 전달.
    var onMoved: ((NSPoint) -> Void)?

    private static let defaultSize = NSSize(width: 180, height: 180)

    init(displayMode: DisplayMode) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true   // 배경 드래그로 이동
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // 백그라운드에서도 닫히지 않게 패널 기본 동작 유지
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        applyDisplayMode(displayMode)
    }

    // borderless 창도 키/메인이 될 수 있어야 드래그·상호작용이 자연스럽다.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 표시 모드에 맞춰 윈도우 레벨 적용.
    func applyDisplayMode(_ mode: DisplayMode) {
        level = mode.windowLevel
    }

    /// 저장된 위치로 복원. 없거나 화면 밖이면 화면 우상단 근처에 배치.
    func restoreFrame(savedOrigin: NSPoint?) {
        if let origin = savedOrigin, isVisibleOnAnyScreen(origin) {
            setFrameOrigin(origin)
        } else if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.maxX - Self.defaultSize.width - 40,
                y: visible.maxY - Self.defaultSize.height - 40
            )
            setFrameOrigin(origin)
        }
    }

    /// 배율 변경 시 콘텐츠 크기 적용. 좌상단(화면 기준 위쪽)을 고정한 채 커지고 줄어듦.
    /// 커져서 화면을 벗어나면 화면 안으로 다시 밀어넣는다.
    func applyScale(_ scale: CGFloat) {
        let newSize = NSSize(width: LayoutStore.baseSize.width * scale,
                             height: LayoutStore.baseSize.height * scale)
        let topY = frame.maxY                 // 위쪽 변 유지
        setContentSize(newSize)
        var f = frame
        f.origin.y = topY - f.height
        setFrame(clampedToScreen(f), display: true)
    }

    /// 프레임이 (가장 많이 걸친) 화면의 작업영역 안에 완전히 들어오게 보정.
    private func clampedToScreen(_ rect: NSRect) -> NSRect {
        let screen = NSScreen.screens.max {
            ($0.frame.intersection(rect)).area < ($1.frame.intersection(rect)).area
        } ?? NSScreen.main ?? NSScreen.screens.first
        guard let vis = screen?.visibleFrame else { return rect }
        var r = rect
        // 화면보다 크면 좌상단 기준으로 맞춤.
        r.origin.x = r.width  >= vis.width  ? vis.minX
                                            : min(max(r.minX, vis.minX), vis.maxX - r.width)
        r.origin.y = r.height >= vis.height ? vis.maxY - r.height
                                            : min(max(r.minY, vis.minY), vis.maxY - r.height)
        return r
    }

    // 배경 드래그 이동 중에도 실시간으로 화면 안에 가둠.
    override func setFrameOrigin(_ point: NSPoint) {
        let proposed = NSRect(origin: point, size: frame.size)
        super.setFrameOrigin(clampedToScreen(proposed).origin)
    }

    /// 그 위치에 뒀을 때 위젯의 절반 이상이 어떤 화면에든 보이는지.
    private func isVisibleOnAnyScreen(_ origin: NSPoint) -> Bool {
        let rect = NSRect(origin: origin, size: Self.defaultSize)
        let minVisible = rect.width * rect.height * 0.5
        for screen in NSScreen.screens {
            let inter = screen.frame.intersection(rect)
            if !inter.isNull, inter.width * inter.height >= minVisible {
                return true
            }
        }
        return false
    }

    // 드래그가 끝나면 위치 저장.
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMoved?(frame.origin)
    }
}

private extension NSRect {
    /// 면적. null/empty면 0.
    var area: CGFloat {
        (isNull || isEmpty) ? 0 : width * height
    }
}
