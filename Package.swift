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
        .package(path: "Vendor/ZIPFoundation")
    ],
    targets: [
        .target(
            name: "RightClickCore",
            dependencies: ["ZIPFoundation"]
        ),
        .testTarget(
            name: "RightClickCoreTests",
            dependencies: ["RightClickCore"]
        )
    ]
)
