// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContainerDeskCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ContainerDeskCore",
            targets: ["ContainerDeskCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ContainerDeskCore",
            dependencies: []
        ),
        .testTarget(
            name: "ContainerDeskCoreTests",
            dependencies: ["ContainerDeskCore"]
        ),
    ]
)
