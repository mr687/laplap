// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "laplap",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "laplap",
            path: "Sources/laplap"
        ),
        .testTarget(
            name: "laplapTests",
            dependencies: ["laplap"],
            path: "Tests/laplapTests"
        ),
    ]
)
