import SwiftUI
import AppKit

/// 사진 편집 시트 — 배경 제거 + 자르기. "적용"하면 편집 결과 PNG 데이터를 콜백으로 넘긴다.
struct ImageEditorView: View {
    let original: NSImage
    var onCancel: () -> Void
    var onApply: (Data) -> Void

    @State private var working: NSImage
    @State private var isCropping = false
    /// 자르기 영역(정규화 0~1, 좌상단 기준).
    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var dragStartCrop: CGRect?
    @State private var processing = false
    @State private var isZooming = false
    /// 확대/축소 배율(미적용 미리보기용). 적용하면 working 에 반영.
    @State private var zoom: CGFloat = 1

    init(original: NSImage, onCancel: @escaping () -> Void, onApply: @escaping (Data) -> Void) {
        self.original = original
        self.onCancel = onCancel
        self.onApply = onApply
        _working = State(initialValue: original)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("사진 편집").font(.headline)
            imageArea
            toolbar
        }
        .padding(16)
        .frame(width: 440, height: 500)
    }

    // MARK: - 이미지 영역

    private var imageArea: some View {
        GeometryReader { geo in
            let fit = fitRect(imageSize: working.size, in: geo.size)
            ZStack {
                // 캔버스(=출력 영역)만 체커보드. 전체 영역이 아니라 실제 캔버스 크기에 맞춤
                // → 잘림이 어디서 일어나는지(캔버스 경계) 명확.
                checkerboard
                    .frame(width: fit.width, height: fit.height)
                    .position(x: fit.midX, y: fit.midY)

                // 이미지: 캔버스에 맞춰 그리고, 넘치면 캔버스 경계에서 잘림(WYSIWYG).
                Image(nsImage: working)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .frame(width: fit.width, height: fit.height)
                    .clipped()
                    .position(x: fit.midX, y: fit.midY)

                // 캔버스 경계선.
                Rectangle()
                    .path(in: fit)
                    .stroke(.white.opacity(0.6), lineWidth: 1)

                if isCropping {
                    cropOverlay(fit: fit, container: geo.size)
                }

                if processing {
                    Color.black.opacity(0.35)
                    ProgressView("배경 분리 중…")
                        .controlSize(.large)
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(height: 340)
    }

    /// 투명 영역이 보이도록 체커보드 배경.
    private var checkerboard: some View {
        Canvas { ctx, size in
            let t: CGFloat = 10
            for y in stride(from: 0, to: size.height, by: t) {
                for x in stride(from: 0, to: size.width, by: t) {
                    let dark = (Int(x / t) + Int(y / t)) % 2 == 0
                    ctx.fill(Path(CGRect(x: x, y: y, width: t, height: t)),
                             with: .color(.gray.opacity(dark ? 0.22 : 0.10)))
                }
            }
        }
    }

    // MARK: - 자르기 오버레이

    private func cropOverlay(fit: CGRect, container: CGSize) -> some View {
        let r = viewRect(crop, in: fit)
        return ZStack {
            // 자를 영역 바깥 어둡게.
            Path { p in
                p.addRect(CGRect(origin: .zero, size: container))
                p.addRect(r)
            }
            .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))

            Rectangle()
                .path(in: r)
                .stroke(.white, lineWidth: 1.5)

            // 영역 전체 드래그로 이동.
            Color.white.opacity(0.001)
                .frame(width: r.width, height: r.height)
                .position(x: r.midX, y: r.midY)
                .gesture(moveGesture(fit: fit))

            ForEach(Corner.allCases) { corner in
                let p = handlePoint(corner, r)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                    .frame(width: 14, height: 14)
                    .position(x: p.x, y: p.y)
                    .gesture(cornerGesture(corner, fit: fit))
            }
        }
    }

    // MARK: - 툴바

    @ViewBuilder
    private var toolbar: some View {
        if isCropping {
            HStack {
                Text("자를 영역을 드래그하세요").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("취소") { isCropping = false }
                Button("이 영역으로 자르기") {
                    if let cropped = ImageEditing.crop(working, to: crop) { working = cropped }
                    crop = CGRect(x: 0, y: 0, width: 1, height: 1)
                    isCropping = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(crop.width > 0.99 && crop.height > 0.99)
            }
        } else if isZooming {
            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value: $zoom, in: 0.3...3)
                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                Text("\(Int((zoom * 100).rounded()))%")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                Button("취소") { zoom = 1; isZooming = false }
                Button("적용") {
                    if let scaled = ImageEditing.scaled(working, factor: zoom) { working = scaled }
                    zoom = 1
                    isZooming = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(abs(zoom - 1) < 0.01)
            }
        } else {
            HStack(spacing: 10) {
                Button { removeBackground() } label: {
                    Label("배경 제거", systemImage: "person.and.background.dotted")
                }
                .disabled(processing)

                Button { crop = .init(x: 0, y: 0, width: 1, height: 1); isCropping = true } label: {
                    Label("자르기", systemImage: "crop")
                }
                .disabled(processing)

                Button { zoom = 1; isZooming = true } label: {
                    Label("크기 조절", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                }
                .disabled(processing)

                Button { working = original } label: {
                    Label("되돌리기", systemImage: "arrow.uturn.backward")
                }
                .disabled(processing || working === original)

                Spacer()

                Button("취소") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("적용") {
                    if let data = ImageEditing.pngData(working) { onApply(data) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(processing)
            }
        }
    }

    private func removeBackground() {
        guard let input = ImageEditing.pngData(working) else { return }
        processing = true
        Task {
            let output = await Task.detached { ImageEditing.removeBackgroundPNG(input) }.value
            if let output, let img = NSImage(data: output) {
                working = img
            } else {
                NSSound.beep()   // 피사체를 못 찾음
            }
            processing = false
        }
    }

    // MARK: - 좌표 계산

    private enum Corner: CaseIterable, Identifiable {
        case tl, tr, bl, br
        var id: Self { self }
    }

    /// scaledToFit 으로 그려질 때 이미지가 차지하는 사각형(컨테이너 좌표).
    private func fitRect(imageSize s: CGSize, in c: CGSize) -> CGRect {
        guard s.width > 0, s.height > 0 else { return CGRect(origin: .zero, size: c) }
        let k = min(c.width / s.width, c.height / s.height)
        let w = s.width * k, h = s.height * k
        return CGRect(x: (c.width - w) / 2, y: (c.height - h) / 2, width: w, height: h)
    }

    /// 정규화 crop → 화면 사각형.
    private func viewRect(_ n: CGRect, in fit: CGRect) -> CGRect {
        CGRect(x: fit.minX + n.minX * fit.width,
               y: fit.minY + n.minY * fit.height,
               width: n.width * fit.width,
               height: n.height * fit.height)
    }

    private func handlePoint(_ corner: Corner, _ r: CGRect) -> CGPoint {
        switch corner {
        case .tl: return CGPoint(x: r.minX, y: r.minY)
        case .tr: return CGPoint(x: r.maxX, y: r.minY)
        case .bl: return CGPoint(x: r.minX, y: r.maxY)
        case .br: return CGPoint(x: r.maxX, y: r.maxY)
        }
    }

    private func moveGesture(fit: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { v in
                let start = dragStartCrop ?? crop
                if dragStartCrop == nil { dragStartCrop = crop }
                var x = start.minX + v.translation.width / fit.width
                var y = start.minY + v.translation.height / fit.height
                x = min(max(0, x), 1 - start.width)
                y = min(max(0, y), 1 - start.height)
                crop = CGRect(x: x, y: y, width: start.width, height: start.height)
            }
            .onEnded { _ in dragStartCrop = nil }
    }

    private func cornerGesture(_ corner: Corner, fit: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { v in
                let start = dragStartCrop ?? crop
                if dragStartCrop == nil { dragStartCrop = crop }
                let dx = v.translation.width / fit.width
                let dy = v.translation.height / fit.height
                var (minX, minY, maxX, maxY) = (start.minX, start.minY, start.maxX, start.maxY)
                switch corner {
                case .tl: minX += dx; minY += dy
                case .tr: maxX += dx; minY += dy
                case .bl: minX += dx; maxY += dy
                case .br: maxX += dx; maxY += dy
                }
                let minSize: CGFloat = 0.12
                minX = max(0, min(minX, maxX - minSize))
                maxX = min(1, max(maxX, minX + minSize))
                minY = max(0, min(minY, maxY - minSize))
                maxY = min(1, max(maxY, minY + minSize))
                crop = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }
            .onEnded { _ in dragStartCrop = nil }
    }
}
