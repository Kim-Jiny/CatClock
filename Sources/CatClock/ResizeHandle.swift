import SwiftUI

/// 크기조절 손잡이. AppKit 뷰로 만들어 `mouseDownCanMoveWindow=false` 로
/// 이 영역에선 창이 움직이지 않고 드래그가 크기조절로만 동작하게 한다.
struct ResizeHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ResizeHandleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class ResizeHandleView: NSView {
    private var startScale: CGFloat = 1
    private var startMouse: NSPoint = .zero

    // 이 뷰 위에서 드래그하면 창 이동이 아니라 우리가 처리.
    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startScale = LayoutStore.shared.scale
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let cur = NSEvent.mouseLocation
        // 오른쪽/아래로 끌면 커짐 (화면 좌표는 y가 위로 증가).
        let delta = ((cur.x - startMouse.x) + (startMouse.y - cur.y)) / 220
        LayoutStore.shared.scale = startScale + delta
    }
}
