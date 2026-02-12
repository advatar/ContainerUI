// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContainerDeskCore",
    platforms: [
        .macOS("26.2")
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
    ],
    swiftLanguageModes: [.v6]
)
