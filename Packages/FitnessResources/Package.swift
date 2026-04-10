// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessResources",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessResources", targets: ["FitnessResources"]),
    ],
    targets: [
        .target(name: "FitnessResources"),
        .testTarget(name: "FitnessResourcesTests", dependencies: ["FitnessResources"]),
    ]
)
