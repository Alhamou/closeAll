// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "closeAll",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "closeAllCore", targets: ["closeAllCore"]),
        .executable(name: "closeAll", targets: ["closeAll"]),
    ],
    targets: [
        .target(name: "closeAllCore"),
        .executableTarget(
            name: "closeAll",
            dependencies: ["closeAllCore"]
        ),
        .testTarget(
            name: "closeAllCoreTests",
            dependencies: ["closeAllCore"]
        ),
    ]
)
