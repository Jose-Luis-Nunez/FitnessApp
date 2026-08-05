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
        .package(path: "../FitnessTestSupport"),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            "1.19.2"..<"1.20.0"
        ),
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
                "FitnessTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
