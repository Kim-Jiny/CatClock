import SwiftUI

/// 고양이 스킨(종류). 지금은 SF Symbols + 색으로 표현.
/// 추후 상태별 실제 이미지로 교체할 수 있도록 id 기반으로 분리해 둔다.
struct CatSkin: Identifiable, Equatable {
    let id: String
    let name: String
    let bodyColor: Color
    /// 무늬/포인트 색 (귀 안쪽·시계 등).
    let accent: Color
    /// 삼색냥이 등 다색 패치용 보조 색. nil이면 단색 바디.
    var patch: Color? = nil
    /// 사용자가 넣은 사진을 쓰는 스킨인지.
    var isCustom: Bool = false

    static let all: [CatSkin] = [
        CatSkin(id: "cheese",   name: "치즈냥",   bodyColor: Color(red: 0.95, green: 0.66, blue: 0.30), accent: .white),
        CatSkin(id: "black",    name: "까만냥",   bodyColor: Color(white: 0.22),                         accent: Color(red: 0.55, green: 0.85, blue: 0.95)),
        CatSkin(id: "tuxedo",   name: "턱시도냥", bodyColor: Color(white: 0.30),                         accent: .white),
        CatSkin(id: "gray",     name: "회색냥",   bodyColor: Color(white: 0.62),                         accent: Color(red: 0.96, green: 0.75, blue: 0.80)),
        CatSkin(id: "calico",   name: "삼색냥",
                bodyColor: Color(white: 0.96),
                accent: Color(red: 0.95, green: 0.55, blue: 0.18),
                patch: Color(white: 0.16)),
        CatSkin(id: "white",    name: "흰둥이",   bodyColor: Color(white: 0.92),                         accent: Color(red: 0.95, green: 0.60, blue: 0.65)),
    ]

    /// 사용자 사진 스킨.
    static let custom = CatSkin(id: CustomCat.skinID, name: "내 사진",
                                bodyColor: .gray, accent: .white, isCustom: true)

    static func skin(id: String?) -> CatSkin {
        if id == CustomCat.skinID { return custom }
        return all.first { $0.id == id } ?? all[0]
    }
}
