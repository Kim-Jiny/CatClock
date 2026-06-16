import SwiftUI

/// 고양이 스킨(종류).
/// - 기본 3종(치즈/까만/삼색): SF Symbols + 색으로 합성.
/// - 번들 이미지(`Cats/` 폴더): `imageFile` 로 실제 이미지를 그린다.
/// - 사용자 사진: `isCustom`.
struct CatSkin: Identifiable, Equatable {
    let id: String
    let name: String
    var bodyColor: Color = .gray
    /// 무늬/포인트 색 (귀 안쪽·시계 등).
    var accent: Color = .white
    /// 삼색냥이 등 다색 패치용 보조 색. nil이면 단색 바디.
    var patch: Color? = nil
    /// 사용자가 넣은 사진을 쓰는 스킨인지.
    var isCustom: Bool = false
    /// 번들에 포함된 이미지 파일명(`Cats/` 안). 있으면 SF Symbol 대신 이 이미지로 그린다.
    var imageFile: String? = nil

    /// 이미지 기반(번들/사용자 사진) 스킨인지.
    var isImage: Bool { imageFile != nil }

    /// 기본 고양이 = `Cats/` 폴더에 넣은 번들 이미지들뿐.
    @MainActor
    static var all: [CatSkin] { BundledCat.skins }

    /// 번들 이미지가 하나도 없을 때만 쓰는 안전 폴백(SF Symbol). 이미지가 있으면 안 보임.
    static let fallback = CatSkin(id: "cheese", name: "치즈냥",
                                  bodyColor: Color(red: 0.95, green: 0.66, blue: 0.30), accent: .white)

    /// 목록이 비어도 안전한 기본 스킨.
    @MainActor
    static var defaultSkin: CatSkin { all.first ?? fallback }

    /// 사용자 사진 스킨.
    static let custom = CatSkin(id: CustomCat.skinID, name: "내 사진", isCustom: true)

    @MainActor
    static func skin(id: String?) -> CatSkin {
        if id == CustomCat.skinID { return custom }
        return all.first { $0.id == id } ?? defaultSkin
    }
}
