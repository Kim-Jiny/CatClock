import Observation

/// 선택된 고양이 스킨을 보관·관찰 가능하게 하고 UserDefaults에 저장.
@MainActor
@Observable
final class SkinStore {
    static let shared = SkinStore()

    var selectedID: String {
        didSet { Settings.shared.catSkinID = selectedID }
    }

    var skin: CatSkin { CatSkin.skin(id: selectedID) }

    private init() {
        self.selectedID = Settings.shared.catSkinID ?? CatSkin.all[0].id
    }
}
