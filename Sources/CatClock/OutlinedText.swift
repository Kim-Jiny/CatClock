import SwiftUI

/// 배경 없이 테두리만 있는 두꺼운 글씨(스티커 느낌).
/// SwiftUI엔 텍스트 스트로크가 없어 글자를 8방향으로 깔아 외곽선을 만든다.
struct OutlinedText: View {
    let text: String
    var size: CGFloat = 26
    var fill: Color = .white
    var stroke: Color = .black
    var lineWidth: CGFloat = 2.5

    private var font: Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    private var offsets: [CGSize] {
        let w = lineWidth
        return [
            CGSize(width:  w, height:  0), CGSize(width: -w, height:  0),
            CGSize(width:  0, height:  w), CGSize(width:  0, height: -w),
            CGSize(width:  w, height:  w), CGSize(width: -w, height:  w),
            CGSize(width:  w, height: -w), CGSize(width: -w, height: -w),
        ]
    }

    var body: some View {
        ZStack {
            ForEach(Array(offsets.enumerated()), id: \.offset) { _, o in
                Text(text)
                    .font(font)
                    .monospacedDigit()
                    .foregroundStyle(stroke)
                    .offset(o)
            }
            Text(text)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(fill)
        }
        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
    }
}
