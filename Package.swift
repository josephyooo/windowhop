// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "windowhop",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "windowhop",
            path: "Sources/windowhop"
        )
    ],
    swiftLanguageVersions: [.v5]
)
