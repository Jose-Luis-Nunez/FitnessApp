// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessCore", targets: ["FitnessCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FitnessCore",
            dependencies: []
        ),
        .testTarget(
            name: "FitnessCoreTests",
            dependencies: ["FitnessCore"]
        ),
    ]
)
