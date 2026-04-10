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
        .package(path: "../FitnessStorage"),
    ],
    targets: [
        .target(
            name: "FitnessUI",
            dependencies: ["FitnessCore", "FitnessResources", "FitnessStorage"]
        ),
        .testTarget(
            name: "FitnessUITests",
            dependencies: ["FitnessUI"]
        ),
    ]
)
