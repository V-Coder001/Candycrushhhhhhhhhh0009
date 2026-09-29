// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Match3Core",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Match3Core", targets: ["Match3Core"]),
    ],
    targets: [
        .target(name: "Match3Core"),
        .testTarget(name: "Match3CoreTests", dependencies: ["Match3Core"]),
    ]
)
