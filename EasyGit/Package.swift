// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EasyGit",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "EasyGit",
            path: "Sources/EasyGit"
        )
    ]
)
