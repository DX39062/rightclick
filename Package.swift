// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RightClick",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "RightClickCore", targets: ["RightClickCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "RightClickCore",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .testTarget(
            name: "RightClickCoreTests",
            dependencies: ["RightClickCore"]
        )
    ]
)
