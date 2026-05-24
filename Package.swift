// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReCord",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ReCord", targets: ["ReCord"])
    ],
    targets: [
        .executableTarget(
            name: "ReCord",
            path: "Sources/ReCord",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ReCordTests",
            dependencies: ["ReCord"],
            path: "Tests/ReCordTests"
        )
    ]
)
