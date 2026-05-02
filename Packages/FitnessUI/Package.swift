// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessUI", targets: ["FitnessUI"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessResources"),
    ],
    targets: [
        .target(
            name: "FitnessUI",
            dependencies: ["FitnessCore", "FitnessResources"]
        ),
        .testTarget(
            name: "FitnessUITests",
            dependencies: ["FitnessUI"]
        ),
    ]
)
