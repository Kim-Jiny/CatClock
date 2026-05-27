import SwiftUI
import AppKit

@MainActor
final class AboutViewModel: ObservableObject {
    @Published var currentVersion: String
    @Published var latestVersion: String?
    @Published var loading: Bool = false
    @Published var errorMessage: String?

    private let feedURL: URL?

    init() {
        let info = Bundle.main.infoDictionary
        currentVersion = info?["CFBundleShortVersionString"] as? String ?? "?"
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
            latestVersion = AppcastVersionParser.firstShortVersion(in: data)
            if latestVersion == nil {
                errorMessage = "appcast 파싱 실패"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var hasUpdate: Bool {
        guard let latest = latestVersion else { return false }
        return AppcastVersionParser.compare(latest, currentVersion) == .orderedDescending
    }
}

enum AppcastVersionParser {
    static func firstShortVersion(in data: Data) -> String? {
        let delegate = ShortVersionParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.found
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

private final class ShortVersionParserDelegate: NSObject, XMLParserDelegate {
    var found: String?
    private var capturing = false
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if found == nil, elementName == "sparkle:shortVersionString" {
            capturing = true
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if capturing, elementName == "sparkle:shortVersionString" {
            found = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            capturing = false
            parser.abortParsing()
        }
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
                row(label: "현재 버전", value: viewModel.currentVersion)
                if showsUpdateChannel {
                    Divider()
                    HStack {
                        Text("최신 버전").foregroundStyle(.secondary)
                        Spacer()
                        if viewModel.loading {
                            ProgressView().controlSize(.small)
                        } else if let latest = viewModel.latestVersion {
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
