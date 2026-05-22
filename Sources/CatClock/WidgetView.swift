import SwiftUI

/// 타이머 위젯. 기본 스킨은 둥근 박스, 사용자 사진 스킨은 박스 없이 투명.
///
/// 배율 적용은 `.scaleEffect`(래스터 확대 → 흐림) 대신 **모든 치수에 배율을
/// 곱해 네이티브로 그린다**. 글자·이미지·아이콘이 어느 크기에서도 또렷하다.
struct WidgetView: View {
    @State private var engine = TimerEngine.shared
    @State private var skins = SkinStore.shared
    @State private var layout = LayoutStore.shared
    @State private var hovering = false
    @State private var revealed = false   // 호버숨김 옵션 켜졌을 때, 클릭으로 컨트롤 노출
    @State private var pulse = false
    @State private var dragStartTimerPos: CGPoint?
    @State private var dragStartFont: CGFloat?
    private let settings = Settings.shared

    private var s: CGFloat { layout.scale }
    private var bw: CGFloat { LayoutStore.baseSize.width * s }
    private var bh: CGFloat { LayoutStore.baseSize.height * s }

    /// 상태별 글씨 색. paused 노랑·done 빨강은 상태 강조용으로 고정,
    /// running/idle 만 사용자가 지정한 색.
    private func timeColor(base: Color) -> Color {
        switch engine.state {
        case .done:    return .red
        case .running: return base
        case .paused:  return .yellow
        case .idle:    return base.opacity(0.7)
        }
    }

    /// 카운트 표시 여부. 알람 중에는 옵션과 무관하게 강제로 보임.
    private var showsCount: Bool {
        if engine.isAlerting { return true }
        return !layout.hideCountUnlessHover || hovering
    }

    /// 컨트롤(리사이즈/재생·정지·리셋/시간 위치 핸들) 표시 여부.
    /// 옵션이 켜졌으면 호버 + 클릭 후에만 노출. 옵션 꺼졌으면 기존대로 호버만으로 노출.
    private var showsControls: Bool {
        if engine.isAlerting { return true }
        if layout.hideCountUnlessHover {
            return hovering && revealed
        }
        return hovering
    }

    var body: some View {
        widget
        .frame(width: bw, height: bh)
        .overlay(alignment: .bottomTrailing) { resizeGrip }
        .onHover { h in
            hovering = h
            if !h { revealed = false }
        }
        .onTapGesture {
            if layout.hideCountUnlessHover { revealed = true }
        }
        .onChange(of: engine.isAlerting) { _, alerting in
            withAnimation(alerting
                ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                : .default) {
                pulse = alerting
            }
        }
    }

    /// 우하단 위젯 크기조절 손잡이. 창 이동 차단.
    private var resizeGrip: some View {
        ZStack {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11 * s, weight: .bold))
                .foregroundStyle(.white)
                .padding(5 * s)
                .background(.black.opacity(0.5), in: Circle())
                .opacity(showsControls ? 0.9 : 0)
                .animation(.easeInOut(duration: 0.15), value: showsControls)
            ResizeHandle()
        }
        .frame(width: 30 * s, height: 30 * s)
        .padding(4 * s)
    }

    // MARK: - 위젯 본체 (투명, 박스 없음)

    private var widget: some View {
        let customImg = skins.skin.isCustom ? CustomCat.load() : nil
        let area = imageRect(imgSize: customImg?.size, in: LayoutStore.baseSize)
        let centerBase = clampedTimerCenter(in: area)

        return ZStack {
            // 투명 영역도 잡아서 창 이동.
            Color.white.opacity(0.001)

            catContent(customImg: customImg)

            // 이동·크기 가능한 시간(네이티브 크기로 그려서 또렷함).
            OutlinedText(
                text: engine.displayText,
                size: layout.timerFontSize * s,
                style: TimerTextStyle(
                    fill: timeColor(base: settings.timerFillColor),
                    stroke: settings.timerStrokeColor,
                    lineWidth: max(2, layout.timerFontSize * s * 0.09),
                    font: settings.timerFontStyle,
                    showOutline: settings.timerShowOutline
                )
            )
            .opacity(showsCount ? (engine.isAlerting && pulse ? 0.45 : 1) : 0)
            .animation(.easeInOut(duration: 0.15), value: showsCount)
            .overlay(alignment: .bottomTrailing) {
                timerHandles.allowsHitTesting(showsControls)
            }
            .position(x: centerBase.x * s, y: centerBase.y * s)

            // 컨트롤/끄기: 하단 고정, 마우스 올렸을 때.
            VStack {
                Spacer()
                controls
            }
            .padding(.bottom, 6 * s)
        }
        .frame(width: bw, height: bh)
    }

    /// 고양이 표시. 사용자 사진 스킨이면 PNG, 아니면 SF Symbol 기반 CatView.
    @ViewBuilder
    private func catContent(customImg: NSImage?) -> some View {
        if skins.skin.isCustom {
            if let img = customImg {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: bw, height: bh)
                    .scaleEffect(engine.state == .done ? 1.04 : 1)
                    .animation(.spring(duration: 0.35), value: engine.state)
            } else {
                VStack(spacing: 4 * s) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 34 * s))
                    Text("설정에서 사진을 골라주세요")
                        .font(.system(size: 11 * s))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
        } else {
            // 위젯 크기에 어울리게 키워 표시. CatView 자체는 height 70*scale 기준.
            CatView(skin: skins.skin, state: engine.state, scale: s * 1.6)
        }
    }

    /// 시간 위 핸들: 전체=이동, 우하단 작은 점=크기조절. (창 이동 차단)
    private var timerHandles: some View {
        ZStack(alignment: .bottomTrailing) {
            DragCatcher(
                onChanged: { d in
                    let base = LayoutStore.baseSize
                    if dragStartTimerPos == nil { dragStartTimerPos = layout.timerPos }
                    let start = dragStartTimerPos ?? layout.timerPos
                    // 화면 픽셀 변위 → 위젯 정규화 좌표 변위.
                    let nx = start.x + d.width  / (base.width  * layout.scale)
                    let ny = start.y - d.height / (base.height * layout.scale)
                    layout.timerPos = CGPoint(x: min(1, max(0, nx)),
                                              y: min(1, max(0, ny)))
                },
                onEnded: { dragStartTimerPos = nil }
            )

            ZStack {
                Circle().fill(.black.opacity(0.55))
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(.white)
                DragCatcher(
                    onChanged: { d in
                        if dragStartFont == nil { dragStartFont = layout.timerFontSize }
                        let f = dragStartFont ?? layout.timerFontSize
                        // 위젯 배율과 무관하게 일정한 체감 → 배율로 나눠 base 단위 변경.
                        layout.timerFontSize = f + (d.width + d.height) / (4 * layout.scale)
                    },
                    onEnded: { dragStartFont = nil }
                )
            }
            .frame(width: 18 * s, height: 18 * s)
            .offset(x: 9 * s, y: 9 * s)
            .opacity(showsControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: showsControls)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if engine.isAlerting {
            Button {
                engine.acknowledge()
            } label: {
                Label("끄기", systemImage: "bell.slash.fill")
                    .font(.system(size: 12 * s, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            HStack(spacing: 18 * s) {
                Button(action: engine.toggle) {
                    Image(systemName: playPauseIcon)
                }
                Button(action: engine.reset) {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .font(.system(size: 14 * s, weight: .bold))
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.7), radius: 2 * s)
            .opacity(showsControls ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: showsControls)
        }
    }

    // MARK: - 시간 배치 계산 (base 좌표)

    /// scaledToFit 으로 보일 때 이미지가 실제 차지하는 사각형(base 좌표, 좌상단 기준).
    private func imageRect(imgSize: CGSize?, in base: CGSize) -> CGRect {
        guard let s = imgSize, s.width > 0, s.height > 0 else {
            return CGRect(origin: .zero, size: base)
        }
        let k = min(base.width / s.width, base.height / s.height)
        let w = s.width * k, h = s.height * k
        return CGRect(x: (base.width - w) / 2, y: (base.height - h) / 2,
                      width: w, height: h)
    }

    /// 저장된 정규화 위치를 base 좌표 중심점으로 변환하고, 글자가 이미지 밖으로
    /// 나가지 않게 가둠. (반환값은 base 좌표; 호출처에서 배율 곱해 .position 적용)
    private func clampedTimerCenter(in area: CGRect) -> CGPoint {
        let base = LayoutStore.baseSize
        let fs = layout.timerFontSize
        let halfW = CGFloat(engine.displayText.count) * fs * 0.31
        let halfH = fs * 0.62
        var x = layout.timerPos.x * base.width
        var y = layout.timerPos.y * base.height
        let minX = area.minX + halfW, maxX = area.maxX - halfW
        let minY = area.minY + halfH, maxY = area.maxY - halfH
        x = minX <= maxX ? min(max(x, minX), maxX) : area.midX
        y = minY <= maxY ? min(max(y, minY), maxY) : area.midY
        return CGPoint(x: x, y: y)
    }

    private var playPauseIcon: String {
        switch engine.state {
        case .running: return "pause.fill"
        case .done:    return "arrow.clockwise"
        default:       return "play.fill"
        }
    }
}
