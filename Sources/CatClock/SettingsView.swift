import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 타이머 설정 + 고양이 종류 + 자동실행. 메뉴바 "타이머 설정…"에서 열림.
struct SettingsView: View {
    @State private var engine = TimerEngine.shared
    @State private var skins = SkinStore.shared
    @State private var layout = LayoutStore.shared
    private let settings = Settings.shared  // @Observable: SwiftUI 가 read 자동 추적

    // 큰 분류: 집중용 / 출퇴근용
    @State private var category: Category = .focus
    // 출퇴근용 세부: 목표 시각 / 근무 시간
    @State private var offKind: OffKind = .duration

    @State private var minutes = 25
    @State private var offTime = Calendar.current.date(
        bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var workHours = 9
    @State private var workMinutes = 0

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError = false

    enum Category: String, CaseIterable { case focus = "집중용", commute = "출퇴근용" }
    enum OffKind: String, CaseIterable { case clock = "목표 시각", duration = "근무 시간" }

    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                timerTab
                    .tabItem { Label("모드", systemImage: "clock") }
                displayTab
                    .tabItem { Label("표시", systemImage: "paintbrush") }
                alertTab
                    .tabItem { Label("알림", systemImage: "bell") }
                runTab
                    .tabItem { Label("실행", systemImage: "power") }
                catTab
                    .tabItem { Label("고양이", systemImage: "cat") }
            }

            HStack {
                Spacer()
                Button("닫기") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 420, height: 520)
        .onAppear(perform: loadFromEngine)
    }

    // MARK: - 탭 컨테이너

    @ViewBuilder
    private var timerTab: some View {
        @Bindable var settings = settings
        tabScroll {
            Picker("", selection: $settings.widgetMode) {
                ForEach(WidgetMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch settings.widgetMode {
            case .clock:
                clockSection
            case .timer:
                timerModeBody
            }
        }
    }

    private var timerModeBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $category) {
                ForEach(Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch category {
            case .focus:   focusSection
            case .commute: commuteSection
            }

            HStack {
                Spacer()
                Button("적용 후 시작") {
                    apply(); engine.reset(); engine.start(); onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var clockSection: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("지역")
                Spacer()
                Picker("", selection: $settings.clockTimeZoneID) {
                    Text("디바이스 기본 (\(deviceTZLabel))").tag(String?.none)
                    ForEach(ClockRegion.groups, id: \.self) { group in
                        Section(group) {
                            ForEach(regionsByGroup[group] ?? []) { r in
                                Text("\(r.name)  (\(ClockRegion.offsetLabel(for: TimeZone(identifier: r.id) ?? .current)))")
                                    .tag(String?(r.id))
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240)
            }

            Toggle("24시간제", isOn: $settings.clockUse24Hour)
            Toggle("AM/PM 표시", isOn: $settings.clockShowAMPM)
                .disabled(settings.clockUse24Hour)
            Toggle("초 표시", isOn: $settings.clockShowSeconds)

            Text("현재 시각을 표시하는 모드예요. 시작/정지 같은 타이머 컨트롤은 숨겨집니다.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// 지역 묶음별 캐시. 메뉴 그릴 때 매번 필터링하지 않게.
    private var regionsByGroup: [String: [ClockRegion]] {
        Dictionary(grouping: ClockRegion.all, by: \.group)
    }

    /// "Asia/Seoul, UTC+9" 형태의 디바이스 시간대 라벨.
    private var deviceTZLabel: String {
        let tz = TimeZone.current
        return "\(tz.identifier), \(ClockRegion.offsetLabel(for: tz))"
    }

    private var displayTab: some View { tabScroll { displaySection } }
    private var alertTab: some View   { tabScroll { alertSection } }
    private var runTab: some View     { tabScroll { autoLaunchSection } }
    private var catTab: some View     { tabScroll { catSection } }

    /// 탭 공통 컨테이너: 스크롤 + 좌측 정렬 + 일관 패딩.
    @ViewBuilder
    private func tabScroll<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    // MARK: - 집중용

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("집중 시간")
                Spacer()
                numberField($minutes, range: 1...600, width: 56)
                Text("분")
                Stepper("", value: $minutes, in: 1...600).labelsHidden()
            }
            HStack(spacing: 8) {
                ForEach([5, 15, 25, 45, 60], id: \.self) { m in
                    Button("\(m)") { minutes = m }.buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - 출퇴근용

    private var commuteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $offKind) {
                ForEach(OffKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch offKind {
            case .clock:
                HStack {
                    Text("퇴근 시각")
                    Spacer()
                    // 키보드로 입력 가능 + 화살표/스크롤도 됨, 1분 단위.
                    DatePicker("", selection: $offTime,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.field)
                        .labelsHidden()
                }
                Text("이미 지난 시각이면 다음 날 기준으로 계산해요.")
                    .font(.caption).foregroundStyle(.secondary)
            case .duration:
                HStack {
                    Text("근무 시간")
                    Spacer()
                    numberField($workHours, range: 0...23, width: 44)
                    Text("시간")
                    numberField($workMinutes, range: 0...59, width: 44)
                    Text("분")
                }
                Text("시작한 시점부터 이만큼 지나면 '퇴근!' 알림.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 표시 옵션

    @ViewBuilder
    private var displaySection: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 8) {
            Toggle("카운트는 마우스 올렸을 때만 표시",
                   isOn: Binding(
                    get: { layout.hideCountUnlessHover },
                    set: { layout.hideCountUnlessHover = $0 }
                   ))
            Text("위젯에 마우스를 올리지 않으면 시간 숫자가 숨겨져요. 알람 중에는 항상 보입니다.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Text("시간 표시 형식")
                Spacer()
                Picker("", selection: $settings.timerDisplayFormat) {
                    ForEach(TimerDisplayFormat.allCases) { fmt in
                        Text(fmt.title).tag(fmt)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("타이머 글씨체")
                fontStyleGrid
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("타이머 색상")
                HStack {
                    Text("글씨 색")
                    Spacer()
                    ColorPicker("", selection: $settings.timerFillColor, supportsOpacity: false)
                        .labelsHidden()
                }
                HStack {
                    Text("외곽선 색")
                    Spacer()
                    ColorPicker("", selection: $settings.timerStrokeColor, supportsOpacity: false)
                        .labelsHidden()
                        .disabled(!settings.timerShowOutline)
                }
                Toggle("외곽선 표시", isOn: $settings.timerShowOutline)
                Text("일시정지(노랑) / 종료(빨강) 색상은 상태 강조용으로 고정이에요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var fontStyleGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
            ForEach(TimerFontStyle.allCases) { style in
                selectableCard(
                    isSelected: settings.timerFontStyle == style,
                    onTap: { settings.timerFontStyle = style }
                ) {
                    VStack(spacing: 2) {
                        Text("12:34")
                            .font(style.font(size: 22, weight: .bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(style.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - 알림

    @ViewBuilder
    private var alertSection: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 6) {
            Toggle("완료 시 소리 알림", isOn: $settings.soundOnFinish)
            Text("끄면 시각 알림(위젯 깜빡임)만 유지돼요. 4초 간격 반복 소리도 같이 꺼집니다.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - 자동 실행

    @ViewBuilder
    private var autoLaunchSection: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 6) {
            Toggle("로그인 시 CatClock 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    loginError = !LoginItem.set(on)
                    if loginError { launchAtLogin = LoginItem.isEnabled }
                }
            Toggle("실행되면 자동으로 타이머 시작", isOn: $settings.autoStartOnLaunch)
            Text("둘 다 켜면: 로그인 → CatClock 자동 실행 → 위 타이머 자동 시작 (출퇴근용에 딱).")
                .font(.caption).foregroundStyle(.secondary)
            if loginError {
                Text("⚠︎ 로그인 항목 등록 실패 — /Applications 의 정식 서명된 CatClock 에서만 동작합니다.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if !LoginItem.isSupported {
                Text("개발 실행(swift run)에선 자동 실행이 적용되지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 고양이

    @State private var customTick = 0  // 사진 변경 후 미리보기 갱신용
    @State private var editing: EditingItem?

    /// 편집 시트에 넘길 대상(보관함 파일명 + 이미지).
    struct EditingItem: Identifiable {
        let id = UUID()
        let file: String
        let image: NSImage
    }

    private var catSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("고양이 종류").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(CatSkin.all) { s in
                    selectableCard(
                        isSelected: skins.selectedID == s.id,
                        cornerRadius: 10,
                        onTap: { skins.selectedID = s.id }
                    ) {
                        VStack(spacing: 4) {
                            CatView(skin: s, state: .idle).scaleEffect(0.7).frame(height: 56)
                            Text(s.name).font(.caption)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Divider()

            catRotationControl

            Divider()

            // 내 고양이 사진 보관함 (투명 PNG면 모양대로만 보임)
            Text("내 고양이 사진").font(.subheadline.bold())
            Text("등록한 사진은 보관함에 쌓여요. 평소 사진과 완료 사진을 골라 쓸 수 있어요.")
                .font(.caption).foregroundStyle(.secondary)

            photoLibraryGrid
                .id(customTick)

            HStack {
                Button("사진 추가…", action: addPhoto)
                Spacer()
            }
        }
        .sheet(item: $editing) { item in
            ImageEditorView(
                original: item.image,
                onCancel: { editing = nil },
                onApply: { data in saveEdited(data, replacing: item.file); editing = nil }
            )
        }
    }

    /// 위젯 고양이 이미지 회전 각도 조절.
    private var catRotationControl: some View {
        let rotation = Binding(
            get: { settings.catRotation },
            set: { settings.catRotation = $0 }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("고양이 회전").font(.subheadline.bold())
                Spacer()
                Text("\(Int(settings.catRotation.rounded()))°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: rotation, in: 0...360, step: 1)
            HStack(spacing: 8) {
                ForEach([0, 90, 180, 270], id: \.self) { deg in
                    Button("\(deg)°") { settings.catRotation = Double(deg) }
                        .buttonStyle(.bordered)
                }
                Spacer()
            }
            Text("위젯의 고양이 이미지를 원하는 각도로 돌려 고정해요.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// 보관함 그리드. 각 사진을 탭하면 평소 사진으로, ⋯ 메뉴로 완료 지정·삭제.
    @ViewBuilder
    private var photoLibraryGrid: some View {
        let files = CustomCat.libraryFiles()
        if files.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled").foregroundStyle(.secondary)
                Text("아직 등록한 사진이 없어요. 아래에서 사진을 추가하세요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(files, id: \.self) { libraryCell($0) }
            }
        }
    }

    /// 보관함 사진 한 칸: 썸네일 + 역할 배지 + ⋯ 메뉴.
    private func libraryCell(_ file: String) -> some View {
        let isNormal = CustomCat.selected(.normal) == file
        let isDone = CustomCat.selected(.done) == file
        return ZStack(alignment: .topTrailing) {
            Group {
                if let img = CustomCat.image(named: file) {
                    Image(nsImage: img).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .background(RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.15)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isNormal ? Color.accentColor : .clear, lineWidth: 2)
            )
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 2) {
                    if isNormal { roleBadge("평소", .accentColor) }
                    if isDone { roleBadge("완료", .red) }
                }
                .padding(3)
            }
            .contentShape(Rectangle())
            .onTapGesture { assign(file, to: .normal) }

            Menu {
                Button("평소 사진으로") { assign(file, to: .normal) }
                if isDone {
                    Button("완료 사진 해제") { CustomCat.select(nil, for: .done); customTick += 1 }
                } else {
                    Button("완료 사진으로") { assign(file, to: .done) }
                }
                Divider()
                Button("편집…") { startEdit(file) }
                Button("보관함에서 삭제", role: .destructive) { removePhoto(file) }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
                    .font(.system(size: 16))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(3)
        }
    }

    private func roleBadge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
    }

    /// 그리드 셀 공통: 선택 시 액센트 강조 + 탭 영역. 글씨체·고양이 스킨 둘 다 사용.
    private func selectableCard<Content: View>(
        isSelected: Bool,
        cornerRadius: CGFloat = 8,
        onTap: @escaping () -> Void,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }

    /// 보관함에 사진 추가(여러 장 가능). 평소 사진이 비어 있으면 첫 사진을 평소로 지정.
    private func addPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "보관함에 추가할 고양이 사진을 고르세요 (투명 PNG 권장)"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        var firstAdded: String?
        for url in panel.urls {
            if let name = CustomCat.add(from: url), firstAdded == nil { firstAdded = name }
        }
        if CustomCat.selected(.normal) == nil, let f = firstAdded {
            CustomCat.select(f, for: .normal)
            skins.selectedID = CustomCat.skinID
        }
        customTick += 1
    }

    /// 보관함 사진을 평소/완료로 지정. 평소로 지정하면 커스텀 스킨도 함께 선택.
    private func assign(_ file: String, to slot: CustomCat.Slot) {
        CustomCat.select(file, for: slot)
        if slot == .normal { skins.selectedID = CustomCat.skinID }
        customTick += 1
    }

    private func removePhoto(_ file: String) {
        CustomCat.remove(file)
        if CustomCat.selected(.normal) == nil && skins.selectedID == CustomCat.skinID {
            skins.selectedID = CatSkin.defaultSkin.id
        }
        customTick += 1
    }

    private func startEdit(_ file: String) {
        guard let img = CustomCat.image(named: file) else { return }
        editing = EditingItem(file: file, image: img)
    }

    /// 편집 결과를 보관함에 새 사진으로 추가하고, 원본이 맡던 평소/완료 역할을 그쪽으로 옮긴다.
    /// (원본 사진은 보관함에 그대로 남겨 둠)
    private func saveEdited(_ data: Data, replacing old: String) {
        guard let newName = CustomCat.addPNG(data) else { return }
        CustomCat.transferRoles(from: old, to: newName)
        customTick += 1
    }

    // MARK: - 동기화

    private func loadFromEngine() {
        switch engine.mode {
        case .task(let m):
            category = .focus; minutes = m
        case .workOff(let h, let mm):
            category = .commute; offKind = .clock
            offTime = Calendar.current.date(
                bySettingHour: h, minute: mm, second: 0, of: Date()) ?? offTime
        case .workDuration(let h, let mm):
            category = .commute; offKind = .duration; workHours = h; workMinutes = mm
        }
        launchAtLogin = LoginItem.isEnabled
    }

    private func apply() {
        switch category {
        case .focus:
            engine.mode = .task(minutes: minutes)
        case .commute:
            switch offKind {
            case .clock:
                let c = Calendar.current.dateComponents([.hour, .minute], from: offTime)
                engine.mode = .workOff(hour: c.hour ?? 18, minute: c.minute ?? 0)
            case .duration:
                engine.mode = .workDuration(hours: workHours, minutes: workMinutes)
            }
        }
    }

    /// 키보드로 직접 입력 가능한 정수 입력칸 (범위 클램프).
    private func numberField(_ value: Binding<Int>, range: ClosedRange<Int>, width: CGFloat) -> some View {
        TextField("", value: Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(range.upperBound, max(range.lowerBound, $0)) }
        ), format: .number)
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
        .frame(width: width)
    }
}
