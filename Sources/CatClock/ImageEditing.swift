import AppKit
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// 사진 편집 유틸 — 자르기(동기)와 배경 제거(Vision, 백그라운드).
enum ImageEditing {

    // MARK: - 변환 유틸

    static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// NSImage → PNG 데이터(투명 보존).
    static func pngData(_ image: NSImage) -> Data? {
        guard let cg = cgImage(from: image) else { return nil }
        return pngData(from: cg)
    }

    nonisolated static func pngData(from cg: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    // MARK: - 자르기

    /// 정규화 사각형(0~1, 좌상단 기준)으로 이미지를 잘라 새 NSImage 반환.
    static func crop(_ image: NSImage, to normalized: CGRect) -> NSImage? {
        guard let cg = cgImage(from: image) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let px = CGRect(x: normalized.minX * w, y: normalized.minY * h,
                        width: normalized.width * w, height: normalized.height * h).integral
        guard px.width >= 1, px.height >= 1, let out = cg.cropping(to: px) else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: out.width, height: out.height))
    }

    // MARK: - 확대/축소

    /// 캔버스(=원본 크기)는 그대로 두고 가운데 기준으로 배율 적용.
    /// factor>1 이면 확대(캔버스 밖은 잘림), factor<1 이면 축소(둘레 투명 여백).
    static func scaled(_ image: NSImage, factor: CGFloat) -> NSImage? {
        guard factor > 0, abs(factor - 1) > 0.001, let cg = cgImage(from: image) else { return nil }
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        let dw = CGFloat(w) * factor, dh = CGFloat(h) * factor
        let rect = CGRect(x: (CGFloat(w) - dw) / 2, y: (CGFloat(h) - dh) / 2, width: dw, height: dh)
        ctx.draw(cg, in: rect)   // 캔버스(0,0,w,h) 밖은 자동으로 잘림
        guard let out = ctx.makeImage() else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: w, height: h))
    }

    // MARK: - 배경 제거 (Vision, 백그라운드 스레드용)

    /// PNG 데이터를 받아 전경(피사체)만 남긴 PNG 데이터 반환. 실패 시 nil.
    /// nonisolated 라 `Task.detached` 에서 메인 스레드 막지 않고 돌릴 수 있다.
    nonisolated static func removeBackgroundPNG(_ input: Data) -> Data? {
        guard let src = CGImageSourceCreateWithData(input as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return nil }
            let buffer = try result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: true)   // 피사체 바깥 여백은 잘라냄
            let ci = CIImage(cvPixelBuffer: buffer)
            guard let outCG = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
            return pngData(from: outCG)
        } catch {
            NSLog("배경 제거 실패: \(error.localizedDescription)")
            return nil
        }
    }
}
