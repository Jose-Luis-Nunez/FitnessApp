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
        .package(path: "../FitnessTestSupport"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", "1.19.2"..<"1.20.0"),
    ],
    targets: [
        .target(
            name: "FitnessUI",
            dependencies: ["FitnessCore", "FitnessResources"]
        ),
        .testTarget(
            name: "FitnessUITests",
            dependencies: [
                "FitnessUI",
                "FitnessTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
