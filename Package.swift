// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JSONViewer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "JSONCore", targets: ["JSONCore"])
    ],
    targets: [
        .target(name: "JSONCore"),
        .testTarget(name: "JSONCoreTests", dependencies: ["JSONCore"])
    ]
)
