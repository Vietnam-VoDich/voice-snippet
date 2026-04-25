// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceSnippet",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceSnippet",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ],
            path: "Sources/VoiceSnippet"
        )
    ]
)
