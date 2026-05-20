import SwiftUI

/// 드래그를 가로채 "창 이동"을 막고(누적) 화면좌표 변위를 콜백으로 준다.
/// y는 화면 기준(위로 +). 시간 숫자 이동/크기조절에 사용.
struct DragCatcher: NSViewRepresentable {
    var onChanged: (CGSize) -> Void
    var onEnded: () -> Void = {}

    func makeNSView(context: Context) -> NSView {
        let v = View()
        v.onChanged = onChanged
        v.onEnded = onEnded
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? View else { return }
        v.onChanged = onChanged
        v.onEnded = onEnded
    }

    final class View: NSView {
        var onChanged: ((CGSize) -> Void)?
        var onEnded: (() -> Void)?
        private var start = NSPoint.zero

        override var mouseDownCanMoveWindow: Bool { false }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            start = NSEvent.mouseLocation
        }

        override func mouseDragged(with event: NSEvent) {
            let cur = NSEvent.mouseLocation
            onChanged?(CGSize(width: cur.x - start.x,
                              height: cur.y - start.y))
        }

        override func mouseUp(with event: NSEvent) {
            onEnded?()
        }
    }
}
