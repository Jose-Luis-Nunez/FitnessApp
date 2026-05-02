// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessProfile",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessProfile", targets: ["FitnessProfile"]),
    ],
    dependencies: [
        .package(path: "../FitnessUI"),
    ],
    targets: [
        .target(
            name: "FitnessProfile",
            dependencies: ["FitnessUI"]
        ),
        .testTarget(
            name: "FitnessProfileTests",
            dependencies: [
                "FitnessProfile",
            ]
        ),
    ]
)
