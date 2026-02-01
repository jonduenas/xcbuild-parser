// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "xcbuild-parser",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "xcbuild-parser", targets: ["xcbuild-parser"]),
        .library(name: "XcodeBuildParserCore", targets: ["XcodeBuildParserCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .target(
            name: "XcodeBuildParserCore",
            path: "Sources/XcodeBuildParserCore"
        ),
        .executableTarget(
            name: "xcbuild-parser",
            dependencies: ["XcodeBuildParserCore"],
            path: "Sources/xcbuild-parser"
        ),
        .testTarget(
            name: "XcodeBuildParserCoreTests",
            dependencies: [
                "XcodeBuildParserCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/XcodeBuildParserCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
