// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PomoBlackHole",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PomoBlackHole", targets: ["PomoBlackHole"])
    ],
    targets: [
        .executableTarget(
            name: "PomoBlackHole",
            path: "Sources/PomoBlackHole"
        ),
        .testTarget(
            name: "PomoBlackHoleTests",
            dependencies: ["PomoBlackHole"],
            path: "Tests/PomoBlackHoleTests"
        )
    ]
)
