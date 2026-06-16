import SwiftUI

/// 위젯(창) 중심을 기준으로 마우스를 빙 돌리면, 누른 시점부터의 누적 회전량(도)을
/// 콜백으로 준다. 반시계가 +(화면 좌표 y는 위로 증가). AppKit 뷰라
/// `mouseDownCanMoveWindow=false` 로 이 손잡이 위에선 창이 움직이지 않는다.
struct RotateCatcher: NSViewRepresentable {
    var onChanged: (Double) -> Void
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
        var onChanged: ((Double) -> Void)?
        var onEnded: (() -> Void)?
        private var lastAngle: Double = 0
        private var accumulated: Double = 0

        override var mouseDownCanMoveWindow: Bool { false }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        /// 창 중심 기준, 현재 마우스의 각도(도).
        private func angleToMouse() -> Double? {
            guard let window else { return nil }
            let m = NSEvent.mouseLocation
            let cx = window.frame.midX, cy = window.frame.midY
            return atan2(Double(m.y - cy), Double(m.x - cx)) * 180 / .pi
        }

        override func mouseDown(with event: NSEvent) {
            lastAngle = angleToMouse() ?? 0
            accumulated = 0
        }

        override func mouseDragged(with event: NSEvent) {
            guard let cur = angleToMouse() else { return }
            var d = cur - lastAngle
            if d > 180 { d -= 360 } else if d < -180 { d += 360 }   // 한 바퀴 경계 보정
            accumulated += d
            lastAngle = cur
            onChanged?(accumulated)
        }

        override func mouseUp(with event: NSEvent) {
            onEnded?()
        }
    }
}
