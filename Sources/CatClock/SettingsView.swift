import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 타이머 설정 + 고양이 종류 + 자동실행. 메뉴바 "타이머 설정…"에서 열림.
struct SettingsView: View {
    @State private var engine = TimerEngine.shared
    @State private var skins = SkinStore.shared

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
    @State private var autoStart = Settings.shared.autoStartOnLaunch
    @State private var loginError = false

    enum Category: String, CaseIterable { case focus = "집중용", commute = "출퇴근용" }
    enum OffKind: String, CaseIterable { case clock = "목표 시각", duration = "근무 시간" }

    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("타이머 설정").font(.title3.bold())

            Picker("", selection: $category) {
                ForEach(Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch category {
            case .focus:   focusSection
            case .commute: commuteSection
            }

            Divider()
            autoLaunchSection

            Divider()
            catSection

            HStack {
                Spacer()
                Button("닫기") { onClose() }
                Button("적용 후 시작") {
                    apply(); engine.reset(); engine.start(); onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear(perform: loadFromEngine)
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

    // MARK: - 자동 실행

    private var autoLaunchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("로그인 시 CatClock 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    loginError = !LoginItem.set(on)
                    if loginError { launchAtLogin = LoginItem.isEnabled }
                }
            Toggle("실행되면 자동으로 타이머 시작", isOn: $autoStart)
                .onChange(of: autoStart) { _, on in
                    Settings.shared.autoStartOnLaunch = on
                }
            Text("둘 다 켜면: 로그인 → CatClock 자동 실행 → 위 타이머 자동 시작 (출퇴근용에 딱).")
                .font(.caption).foregroundStyle(.secondary)
            if loginError {
                Text("⚠︎ 로그인 항목 등록 실패 — 정식 .app으로 실행해야 적용돼요 (build_app.sh).")
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

    private var catSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("고양이 종류").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(CatSkin.all) { s in
                    VStack(spacing: 4) {
                        CatView(skin: s, state: .idle).scaleEffect(0.7).frame(height: 56)
                        Text(s.name).font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(skins.selectedID == s.id ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(skins.selectedID == s.id ? Color.accentColor : .clear, lineWidth: 2)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { skins.selectedID = s.id }
                }
            }

            Divider()

            // 내 고양이 사진 (투명 PNG면 모양대로만 보임)
            HStack(spacing: 12) {
                Group {
                    if let img = CustomCat.load() {
                        Image(nsImage: img).resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
                .id(customTick)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.15)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(skins.selectedID == CustomCat.skinID ? Color.accentColor : .clear, lineWidth: 2)
                )
                .onTapGesture {
                    if CustomCat.hasImage { skins.selectedID = CustomCat.skinID }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("내 고양이 사진").font(.subheadline.bold())
                    Text("투명 배경 PNG를 넣으면 박스 없이 모양대로 떠요.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("사진 고르기…", action: pickImage)
                        if CustomCat.hasImage {
                            Button("지우기", role: .destructive, action: clearImage)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "위젯에 쓸 고양이 사진을 고르세요 (투명 PNG 권장)"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if CustomCat.save(from: url) {
            skins.selectedID = CustomCat.skinID
            customTick += 1
        }
    }

    private func clearImage() {
        CustomCat.clear()
        if skins.selectedID == CustomCat.skinID {
            skins.selectedID = CatSkin.all[0].id
        }
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
        autoStart = Settings.shared.autoStartOnLaunch
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
