// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "xcbuild-parser",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "xcbuild-parser", targets: ["xcbuild-parser"])
    ],
    targets: [
        .executableTarget(
            name: "xcbuild-parser",
            path: "Sources/xcbuild-parser"
        )
    ]
)
