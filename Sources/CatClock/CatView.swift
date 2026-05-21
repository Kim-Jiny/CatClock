import SwiftUI

/// 고양이가 알람시계를 들고 있는 모양. SF Symbols 합성.
/// 5단계: 상태별 표정/동작, 6단계: 스킨(종류) 색 적용.
struct CatView: View {
    let skin: CatSkin
    let state: TimerState
    /// 위젯 배율. 1이 기본. 모든 치수에 곱해 네이티브 크기로 그린다(흐려짐 방지).
    var scale: CGFloat = 1

    private var clockSymbol: String {
        state == .done ? "alarm.waves.left.and.right.fill" : "alarmclock.fill"
    }

    /// 상태 뱃지(머리 옆 작은 표시).
    private var badge: (symbol: String, color: Color)? {
        switch state {
        case .idle:    return ("zzz", .white.opacity(0.7))
        case .running: return nil
        case .paused:  return ("pause.fill", .yellow)
        case .done:    return ("exclamationmark.2", .red)
        }
    }

    var body: some View {
        if skin.isCustom {
            customBody
        } else {
            symbolBody
        }
    }

    /// 사용자 사진: 투명 배경 그대로, 모양대로만 보임.
    @ViewBuilder
    private var customBody: some View {
        ZStack(alignment: .topTrailing) {
            if let img = CustomCat.load() {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .saturation(state == .running ? 1 : 0.92)
                    .scaleEffect(state == .done ? 1.06 : 1)
                    .animation(.spring(duration: 0.35), value: state)
            } else {
                VStack(spacing: 4 * scale) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 34 * scale))
                    Text("사진을 골라주세요")
                        .font(.system(size: 11 * scale))
                }
                .foregroundStyle(.white.opacity(0.8))
            }

            if let badge {
                Image(systemName: badge.symbol)
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(badge.color)
                    .padding(4 * scale)
                    .background(.black.opacity(0.45), in: Circle())
            }
        }
        .frame(width: 96 * scale, height: 96 * scale)
        .animation(.spring(duration: 0.3), value: state)
    }

    @ViewBuilder
    private var symbolBody: some View {
        ZStack(alignment: .bottom) {
            // 고양이 몸통 (흰 베이스 + 삼색 패치)
            ZStack {
                Image(systemName: "cat.fill")
                    .font(.system(size: 62 * scale))
                    .foregroundStyle(skin.bodyColor)
                    .symbolEffect(.bounce, value: state == .done)

                if let patch = skin.patch {
                    calicoPatches(patch: patch)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 2 * scale, y: 1 * scale)
            .scaleEffect(state == .running ? 1.0 : 0.98)

            // 들고 있는 알람시계
            Image(systemName: clockSymbol)
                .font(.system(size: 24 * scale))
                .foregroundStyle(.white, skin.accent)
                .symbolRenderingMode(.palette)
                .offset(y: 10 * scale)
                .symbolEffect(.variableColor.iterative,
                              options: .repeating,
                              isActive: state == .running || state == .done)
                .symbolEffect(.bounce, value: state == .done)

            // 상태 뱃지
            if let badge {
                Image(systemName: badge.symbol)
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(badge.color)
                    .padding(4 * scale)
                    .background(.black.opacity(0.35), in: Circle())
                    .offset(x: 30 * scale, y: -34 * scale)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 70 * scale)
        .animation(.spring(duration: 0.3), value: state)
    }

    /// 삼색냥이 무늬: 오렌지 + 어두운 패치를 cat 실루엣 안에서만 보이게 마스크.
    private func calicoPatches(patch: Color) -> some View {
        ZStack {
            Ellipse()
                .fill(skin.accent)
                .frame(width: 26 * scale, height: 22 * scale)
                .offset(x: -13 * scale, y: -16 * scale)
            Ellipse()
                .fill(patch)
                .frame(width: 22 * scale, height: 18 * scale)
                .offset(x: 14 * scale, y: -12 * scale)
            Ellipse()
                .fill(skin.accent)
                .frame(width: 20 * scale, height: 16 * scale)
                .offset(x: 10 * scale, y: 10 * scale)
            Ellipse()
                .fill(patch)
                .frame(width: 16 * scale, height: 14 * scale)
                .offset(x: -12 * scale, y: 8 * scale)
        }
        .frame(width: 62 * scale, height: 62 * scale)
        .mask {
            Image(systemName: "cat.fill")
                .font(.system(size: 62 * scale))
        }
        .allowsHitTesting(false)
    }
}
