import AppKit

/// 사용자가 등록한 고양이 사진들을 앱 지원 폴더의 **보관함**에 쌓아두고 관리.
/// 보관함의 사진 중 평소 모습(.normal)과 완료했을 때 모습(.done)을 각각 골라 쓴다.
/// 새 사진을 골라도 기존 사진은 지우지 않는다.
@MainActor
enum CustomCat {

    nonisolated static let skinID = "custom"

    /// 사진 역할: 평소 모습 / 완료했을 때 모습.
    enum Slot: CaseIterable {
        case normal, done
    }

    /// 앱 지원 폴더(레거시 단일 파일이 있던 곳).
    private static var baseDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("CatClock", isDirectory: true)
    }

    /// 등록한 사진을 모아두는 보관함 폴더.
    private static var libraryDir: URL {
        baseDir.appendingPathComponent("library", isDirectory: true)
    }

    // MARK: - 레거시 마이그레이션

    private static var didMigrate = false

    /// 예전 단일 파일(customCat.* / customCatDone.*)을 보관함으로 옮긴다.
    /// 설정에 저장된 파일명은 그대로라, 옮긴 뒤에도 평소/완료 선택이 유지된다.
    private static func migrateIfNeeded() {
        guard !didMigrate else { return }
        didMigrate = true
        let fm = FileManager.default
        try? fm.createDirectory(at: libraryDir, withIntermediateDirectories: true)
        guard let items = try? fm.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)
        else { return }
        for f in items where f.lastPathComponent.hasPrefix("customCat") && !f.hasDirectoryPath {
            let dest = libraryDir.appendingPathComponent(f.lastPathComponent)
            if !fm.fileExists(atPath: dest.path) {
                try? fm.moveItem(at: f, to: dest)
            }
        }
    }

    // MARK: - 보관함

    /// 보관함의 모든 사진 파일명(등록 순서대로).
    static func libraryFiles() -> [String] {
        migrateIfNeeded()
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: libraryDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles])
        else { return [] }
        return items
            .filter { !$0.hasDirectoryPath }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da < db
            }
            .map(\.lastPathComponent)
    }

    /// 사진을 보관함에 복사. 성공 시 새 파일명, 실패 시 nil. (기존 사진은 건드리지 않음)
    @discardableResult
    static func add(from src: URL) -> String? {
        migrateIfNeeded()
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: libraryDir, withIntermediateDirectories: true)
            let ext = src.pathExtension.isEmpty ? "png" : src.pathExtension
            let name = "cat-\(UUID().uuidString).\(ext)"
            let dest = libraryDir.appendingPathComponent(name)
            try fm.copyItem(at: src, to: dest)
            return name
        } catch {
            NSLog("CustomCat 추가 실패: \(error.localizedDescription)")
            return nil
        }
    }

    /// 편집 결과(PNG 데이터)를 보관함에 새 파일로 저장. 성공 시 새 파일명.
    @discardableResult
    static func addPNG(_ data: Data) -> String? {
        migrateIfNeeded()
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: libraryDir, withIntermediateDirectories: true)
            let name = "cat-\(UUID().uuidString).png"
            try data.write(to: libraryDir.appendingPathComponent(name))
            return name
        } catch {
            NSLog("CustomCat 저장 실패: \(error.localizedDescription)")
            return nil
        }
    }

    /// 한 사진이 맡던 평소/완료 역할을 다른 파일로 옮긴다(편집본으로 교체용).
    static func transferRoles(from old: String, to new: String) {
        for slot in Slot.allCases where selected(slot) == old {
            select(new, for: slot)
        }
    }

    /// 보관함에서 사진 삭제. 평소/완료로 쓰던 사진이면 그 선택도 해제한다.
    static func remove(_ fileName: String) {
        let fm = FileManager.default
        try? fm.removeItem(at: libraryDir.appendingPathComponent(fileName))
        cache[fileName] = nil
        for slot in Slot.allCases where selected(slot) == fileName {
            select(nil, for: slot)
        }
    }

    // MARK: - 평소/완료 선택

    /// 슬롯에 지정된 파일명(없으면 nil).
    static func selected(_ slot: Slot) -> String? {
        switch slot {
        case .normal: return Settings.shared.customCatFileName
        case .done:   return Settings.shared.customCatDoneFileName
        }
    }

    /// 슬롯에 사진 지정(nil 이면 해제).
    static func select(_ fileName: String?, for slot: Slot) {
        switch slot {
        case .normal: Settings.shared.customCatFileName = fileName
        case .done:   Settings.shared.customCatDoneFileName = fileName
        }
    }

    static func hasImage(_ slot: Slot = .normal) -> Bool {
        migrateIfNeeded()
        guard let name = selected(slot) else { return false }
        return FileManager.default.fileExists(atPath: libraryDir.appendingPathComponent(name).path)
    }

    // MARK: - 이미지 로드(파일명 → NSImage 캐시)

    private static var cache: [String: NSImage] = [:]

    /// 보관함의 특정 파일을 NSImage 로 로드(캐시).
    static func image(named fileName: String) -> NSImage? {
        if let cached = cache[fileName] { return cached }
        let url = libraryDir.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path),
              let img = NSImage(contentsOf: url) else { return nil }
        cache[fileName] = img
        return img
    }

    /// 슬롯에 지정된 사진 로드.
    static func load(_ slot: Slot = .normal) -> NSImage? {
        migrateIfNeeded()
        guard let name = selected(slot) else { return nil }
        return image(named: name)
    }
}
