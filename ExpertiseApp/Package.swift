// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExpertiseApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ExpertiseApp",
            path: "ExpertiseApp",
            exclude: ["Info.plist"]
        )
    ]
)
