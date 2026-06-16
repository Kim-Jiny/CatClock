// swift-tools-version: 6.2
import PackageDescription
import Foundation

// CATCLOCK_APPSTORE=1 swift build  → Mac App Store 용 빌드.
// 이 빌드는 Sparkle 을 링크하지 않고 -D APPSTORE 컴파일 플래그가 들어간다.
let isAppStore = Context.environment["CATCLOCK_APPSTORE"] == "1"

let sparkleDependencies: [Package.Dependency] = isAppStore
    ? []
    : [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")]

let sparkleTargetDeps: [Target.Dependency] = isAppStore
    ? []
    : [.product(name: "Sparkle", package: "Sparkle")]

let swiftSettings: [SwiftSetting] = isAppStore
    ? [.define("APPSTORE")]
    : []

let package = Package(
    name: "CatClock",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: sparkleDependencies,
    targets: [
        .executableTarget(
            name: "CatClock",
            dependencies: sparkleTargetDeps,
            path: "Sources/CatClock",
            resources: [
                // 기본 고양이 이미지 폴더. 파일을 넣으면 자동으로 스킨 목록에 추가된다.
                .copy("Cats")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
