// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LaunchpadPlus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "LaunchpadPlus", path: "Sources/LaunchpadPlus")
    ]
)
