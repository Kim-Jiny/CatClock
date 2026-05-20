#!/usr/bin/env swift
// DMG 창 배경 이미지 생성기.
// 사용: swift Resources/make_dmg_bg.swift Resources/dmg_background.png
import AppKit

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dmg_background.png"

// Finder 창 내용영역과 같은 크기.
let W: CGFloat = 540, H: CGFloat = 380

// 1배 픽셀 비트맵에 직접 그려서 Finder에서 의도한 크기로 보이게.
guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(W), pixelsHigh: Int(H),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0),
      let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write("비트맵 생성 실패\n".data(using: .utf8)!)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// --- 배경 (위→아래 그라데이션) ---
let gradient = NSGradient(starting: NSColor(calibratedWhite: 0.99, alpha: 1),
                          ending:   NSColor(calibratedWhite: 0.93, alpha: 1))!
gradient.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

// 좌표 보정: NSImage는 bottom-left 원점, Finder는 top-left.
// 화면상 "위에서 픽셀" → NSImage y = H - 픽셀.
func topY(_ fromTop: CGFloat) -> CGFloat { H - fromTop }

// --- 제목 ---
let title = "CatClock 설치"
let titleAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 0.18, alpha: 1)
]
let titleStr = NSAttributedString(string: title, attributes: titleAttr)
let ts = titleStr.size()
titleStr.draw(at: NSPoint(x: (W - ts.width) / 2, y: topY(60)))

// --- 부제 ---
let subtitle = "아래 CatClock 아이콘을 오른쪽 Applications 폴더로 드래그하세요"
let subAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.40, alpha: 1)
]
let subStr = NSAttributedString(string: subtitle, attributes: subAttr)
let ss = subStr.size()
subStr.draw(at: NSPoint(x: (W - ss.width) / 2, y: topY(100)))

// --- 아이콘 사이 화살표 ---
// 아이콘은 AppleScript에서 (140, 240), (400, 240) 위치에 놓일 예정.
// 그 사이 가운데에 화살표를 그림 (NSImage 좌표).
let arrowY = topY(240)
let arrowColor = NSColor(calibratedWhite: 0.55, alpha: 1)
arrowColor.setStroke()
arrowColor.setFill()

let shaft = NSBezierPath()
shaft.lineWidth = 5
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 215, y: arrowY))
shaft.line(to: NSPoint(x: 320, y: arrowY))
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 335, y: arrowY))
head.line(to: NSPoint(x: 315, y: arrowY + 12))
head.line(to: NSPoint(x: 315, y: arrowY - 12))
head.close()
head.fill()

// --- 하단 도움말 ---
let foot = "옮긴 뒤 Launchpad 또는 응용 프로그램 폴더에서 CatClock을 실행하세요."
let footAttr: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: 1)
]
let footStr = NSAttributedString(string: foot, attributes: footAttr)
let fs = footStr.size()
footStr.draw(at: NSPoint(x: (W - fs.width) / 2, y: topY(345)))

NSGraphicsContext.restoreGraphicsState()

// --- PNG로 저장 ---
guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("PNG 인코딩 실패\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("✓ \(outPath) (\(Int(W))×\(Int(H)))")
} catch {
    FileHandle.standardError.write("저장 실패: \(error)\n".data(using: .utf8)!)
    exit(1)
}
