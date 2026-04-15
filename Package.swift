// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceSnippet",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "VoiceSnippet", path: "Sources/VoiceSnippet")
    ]
)
