// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessCore", targets: ["FitnessCore"]),
    ],
    dependencies: [
        .package(path: "../FitnessResources"),
    ],
    targets: [
        .target(
            name: "FitnessCore",
            dependencies: ["FitnessResources"]
        ),
        .testTarget(
            name: "FitnessCoreTests",
            dependencies: ["FitnessCore"]
        ),
    ]
)
