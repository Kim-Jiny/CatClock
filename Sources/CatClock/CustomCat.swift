import AppKit

/// 사용자가 고른 고양이 사진(투명 PNG 등)을 앱 지원 폴더에 보관·로드.
@MainActor
enum CustomCat {

    nonisolated static let skinID = "custom"

    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("CatClock", isDirectory: true)
    }

    /// 저장된 파일 경로(없으면 nil). 확장자는 원본 유지.
    static var imageURL: URL? {
        guard let saved = Settings.shared.customCatFileName else { return nil }
        let url = dir.appendingPathComponent(saved)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static var hasImage: Bool { imageURL != nil }

    /// 캐시된 NSImage.
    private static var cache: NSImage?

    static func load() -> NSImage? {
        if let cache { return cache }
        guard let url = imageURL, let img = NSImage(contentsOf: url) else { return nil }
        cache = img
        return img
    }

    /// 원본 파일을 복사해 보관. 성공 시 true.
    @discardableResult
    static func save(from src: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let ext = src.pathExtension.isEmpty ? "png" : src.pathExtension
            let dest = dir.appendingPathComponent("customCat.\(ext)")
            // 기존 파일 정리(확장자 다를 수 있음).
            clearFiles()
            try FileManager.default.copyItem(at: src, to: dest)
            Settings.shared.customCatFileName = dest.lastPathComponent
            cache = nil
            return true
        } catch {
            NSLog("CustomCat 저장 실패: \(error.localizedDescription)")
            return false
        }
    }

    static func clear() {
        clearFiles()
        Settings.shared.customCatFileName = nil
        cache = nil
    }

    private static func clearFiles() {
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in items where f.lastPathComponent.hasPrefix("customCat.") {
                try? fm.removeItem(at: f)
            }
        }
    }
}
