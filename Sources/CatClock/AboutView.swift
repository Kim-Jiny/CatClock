import SwiftUI
import AppKit

@MainActor
final class AboutViewModel: ObservableObject {
    @Published var currentVersion: String
    @Published var latestVersion: String?
    @Published var latestBuild: Int?
    @Published var loading: Bool = false
    @Published var errorMessage: String?

    let currentBuild: Int
    private let feedURL: URL?

    init() {
        let info = Bundle.main.infoDictionary
        currentVersion = info?["CFBundleShortVersionString"] as? String ?? "?"
        currentBuild = Int(info?["CFBundleVersion"] as? String ?? "") ?? 0
        if let s = info?["SUFeedURL"] as? String {
            feedURL = URL(string: s)
        } else {
            feedURL = nil
        }
    }

    func refresh() async {
        guard let feedURL else {
            errorMessage = "SUFeedURL 미설정"
            return
        }
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            // 캐시 무시: 최신 appcast 그대로 받는다.
            var req = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData)
            req.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: req)
            if let item = AppcastVersionParser.firstItem(in: data) {
                latestVersion = item.short
                latestBuild = item.build
            } else {
                errorMessage = "appcast 파싱 실패"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 표시버전이 더 높거나, 같은 표시버전이라도 빌드 번호가 더 높으면 업데이트로 본다.
    var hasUpdate: Bool {
        guard let latest = latestVersion else { return false }
        switch AppcastVersionParser.compare(latest, currentVersion) {
        case .orderedDescending: return true
        case .orderedSame:       return (latestBuild ?? 0) > currentBuild
        case .orderedAscending:  return false
        }
    }

    var currentVersionDisplay: String {
        currentBuild > 0 ? "\(currentVersion) (\(currentBuild))" : currentVersion
    }

    var latestVersionDisplay: String? {
        guard let latest = latestVersion else { return nil }
        if let b = latestBuild { return "\(latest) (\(b))" }
        return latest
    }
}

enum AppcastVersionParser {
    /// 최신(첫) item 의 (표시버전, 빌드번호).
    static func firstItem(in data: Data) -> (short: String, build: Int?)? {
        let delegate = ItemParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        guard let short = delegate.shortVersion else { return nil }
        return (short, delegate.build)
    }

    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let ap = a.split(separator: ".").map { Int($0) ?? 0 }
        let bp = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(ap.count, bp.count) {
            let av = i < ap.count ? ap[i] : 0
            let bv = i < bp.count ? bp[i] : 0
            if av < bv { return .orderedAscending }
            if av > bv { return .orderedDescending }
        }
        return .orderedSame
    }
}

/// appcast 첫 item 의 sparkle:shortVersionString 과 sparkle:version(빌드) 를 잡는다.
private final class ItemParserDelegate: NSObject, XMLParserDelegate {
    var shortVersion: String?
    var build: Int?
    private var capturing: String?
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if elementName == "sparkle:shortVersionString", shortVersion == nil {
            capturing = elementName; buffer = ""
        } else if elementName == "sparkle:version", build == nil {
            capturing = elementName; buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing != nil { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard capturing == elementName else { return }
        let val = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "sparkle:shortVersionString" { shortVersion = val }
        else if elementName == "sparkle:version" { build = Int(val) }
        capturing = nil
        if shortVersion != nil, build != nil { parser.abortParsing() }
    }
}

struct AboutView: View {
    @StateObject private var viewModel = AboutViewModel()
    /// nil 이면 자체 업데이트 채널을 사용하지 않는 빌드(MAS) — "최신 버전/업데이트" 영역을 숨긴다.
    var onUpdate: (() -> Void)?
    var onClose: () -> Void

    private var showsUpdateChannel: Bool { onUpdate != nil }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 2) {
                Text("CatClock").font(.title2.weight(.semibold))
                Text("맥 화면 위의 고양이 타이머")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                row(label: "현재 버전", value: viewModel.currentVersionDisplay)
                if showsUpdateChannel {
                    Divider()
                    HStack {
                        Text("최신 버전").foregroundStyle(.secondary)
                        Spacer()
                        if viewModel.loading {
                            ProgressView().controlSize(.small)
                        } else if let latest = viewModel.latestVersionDisplay {
                            Text(latest)
                        } else if let err = viewModel.errorMessage {
                            Text("확인 실패")
                                .foregroundStyle(.red)
                                .help(err)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            if showsUpdateChannel {
                if viewModel.hasUpdate, let onUpdate {
                    Button(action: onUpdate) {
                        Text("지금 업데이트")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if !viewModel.loading, viewModel.latestVersion != nil {
                    Text("최신 버전을 사용 중입니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("닫기", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 320)
        .task {
            if showsUpdateChannel { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
