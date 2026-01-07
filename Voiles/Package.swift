// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Voiles",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Voiles",
            targets: ["Voiles"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Voiles",
            dependencies: [],
            path: "Sources"
        )
    ]
)
