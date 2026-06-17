// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZIPFoundation",
    products: [
        .library(name: "ZIPFoundation", targets: ["ZIPFoundation"])
    ],
    targets: [
        .target(name: "ZIPFoundation")
    ]
)
