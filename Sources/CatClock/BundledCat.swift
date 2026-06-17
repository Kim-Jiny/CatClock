import AppKit

/// 앱에 포함된 기본 고양이 이미지(`Cats/` 폴더)를 읽어 스킨으로 만든다.
/// 파일을 넣으면 파일명(확장자 제외)이 곧 고양이 이름이 되어 자동으로 목록에 추가된다.
@MainActor
enum BundledCat {

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "tif", "heic", "gif", "webp"]

    /// 리소스 번들. `Bundle.module` 은 못 찾으면 fatalError 라서, 직접 안전하게 탐색한다.
    private static let bundle: Bundle? = {
        let name = "CatClock_CatClock.bundle"
        let candidates: [URL?] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
            Bundle(for: BundleToken.self).resourceURL,
            Bundle(for: BundleToken.self).bundleURL,
        ]
        for c in candidates {
            if let url = c?.appendingPathComponent(name), let b = Bundle(url: url) { return b }
        }
        // 리소스가 메인 번들에 직접 들어간 경우(혹시 모를 폴백).
        return Bundle.main
    }()

    /// 파일명 → 실제 URL. 폴더 열거 때 얻은 URL을 그대로 보관해(한글 파일명 재조회 시
    /// 유니코드 정규화 불일치로 nil 나는 문제 회피) 이미지를 직접 연다.
    private static var urlMap: [String: URL] = [:]

    /// 파일명(확장자 제외) → 한글 표시이름. `Cats/names.json` 에서 읽는다.
    /// 파일명은 ASCII 로 두고(코드서명·DMG·pkg 의 유니코드 정규화 문제 회피),
    /// 표시이름만 한글로 분리. 매핑에 없으면 파일명을 그대로 표시이름으로 쓴다.
    private static let displayNames: [String: String] = {
        guard let urls = bundle?.urls(forResourcesWithExtension: "json", subdirectory: "Cats"),
              let url = urls.first(where: { $0.lastPathComponent == "names.json" }),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }()

    /// `Cats/` 폴더의 이미지 → 스킨 목록(표시이름순). 한 번 계산해 캐시.
    static let skins: [CatSkin] = {
        guard let urls = bundle?.urls(forResourcesWithExtension: nil, subdirectory: "Cats") else { return [] }
        let images = urls.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        var map: [String: URL] = [:]
        let result = images.map { url -> CatSkin in
            let file = url.lastPathComponent
            map[file] = url
            let stem = url.deletingPathExtension().lastPathComponent
            let name = displayNames[stem] ?? stem
            // ID 는 표시이름 기반(기존 배포본과 동일 유지) — 내부 식별자라 한글 OK.
            return CatSkin(id: "bundled:\(name)", name: name, imageFile: file)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        urlMap = map
        return result
    }()

    private static var cache: [String: NSImage] = [:]

    /// 스킨의 번들 이미지 로드(캐시).
    static func image(file: String) -> NSImage? {
        if let cached = cache[file] { return cached }
        _ = skins   // urlMap 이 채워지도록 보장
        guard let url = urlMap[file], let img = NSImage(contentsOf: url) else { return nil }
        cache[file] = img
        return img
    }

    private final class BundleToken {}
}
