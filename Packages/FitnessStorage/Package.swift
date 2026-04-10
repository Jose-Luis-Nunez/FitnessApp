// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessStorage",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessStorage", targets: ["FitnessStorage"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
    ],
    targets: [
        .target(
            name: "FitnessStorage",
            dependencies: ["FitnessCore"]
        ),
        .testTarget(
            name: "FitnessStorageTests",
            dependencies: ["FitnessStorage"]
        ),
    ]
)
