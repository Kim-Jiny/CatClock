import SwiftUI
import Observation

/// 위젯 크기 배율을 보관·관찰. 드래그로 조절하고 UserDefaults에 저장.
@MainActor
@Observable
final class LayoutStore {
    static let shared = LayoutStore()

    /// 기준(1.0배) 위젯 크기.
    static let baseSize = CGSize(width: 180, height: 190)
    static let minScale: CGFloat = 0.6
    static let maxScale: CGFloat = 3.0

    /// 크기가 바뀔 때 패널 쪽에 알림.
    @ObservationIgnored var onScaleChange: ((CGFloat) -> Void)?

    var scale: CGFloat = 1 {
        didSet {
            let clamped = min(Self.maxScale, max(Self.minScale, scale))
            if clamped != scale { scale = clamped; return }   // 한 번 더 들어와 멈춤
            Settings.shared.widgetScale = Double(scale)
            onScaleChange?(scale)
        }
    }

    var scaledSize: CGSize {
        CGSize(width: Self.baseSize.width * scale,
               height: Self.baseSize.height * scale)
    }

    // MARK: - 시간 숫자 위치/크기 (이미지 안에서 자유 배치)

    static let timerFontRange: ClosedRange<CGFloat> = 12...90

    /// 위젯 기준 정규화 좌표(0~1). 기본은 하단 중앙.
    var timerPos: CGPoint = CGPoint(x: 0.5, y: 0.88) {
        didSet { Settings.shared.timerPos = timerPos }
    }

    var timerFontSize: CGFloat = 30 {
        didSet {
            let c = min(Self.timerFontRange.upperBound,
                        max(Self.timerFontRange.lowerBound, timerFontSize))
            if c != timerFontSize { timerFontSize = c; return }
            Settings.shared.timerFontSize = Double(timerFontSize)
        }
    }

    /// 켜면 카운트(시간 숫자)는 위젯에 마우스를 올렸을 때만 보임.
    var hideCountUnlessHover: Bool = false {
        didSet { Settings.shared.hideCountUnlessHover = hideCountUnlessHover }
    }

    private init() {
        let saved = CGFloat(Settings.shared.widgetScale)
        scale = (saved >= Self.minScale && saved <= Self.maxScale) ? saved : 1

        if let p = Settings.shared.timerPos { timerPos = p }
        let fs = CGFloat(Settings.shared.timerFontSize)
        if Self.timerFontRange.contains(fs) { timerFontSize = fs }
        hideCountUnlessHover = Settings.shared.hideCountUnlessHover
    }
}
