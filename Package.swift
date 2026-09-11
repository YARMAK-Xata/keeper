// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Keeper",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Keeper", path: "Sources/Keeper", resources: [.process("Resources")]),
        .testTarget(name: "KeeperTests", dependencies: ["Keeper"], path: "Tests/KeeperTests"),
    ]
)
