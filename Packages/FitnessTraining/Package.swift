// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessTraining",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessTraining", targets: ["FitnessTraining"]),
        .library(name: "FitnessTrainingTestSupport", targets: ["FitnessTrainingTestSupport"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessAnalytics"),
        .package(path: "../FitnessUI"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
        .package(path: "../FitnessTestSupport"),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            "1.19.2"..<"1.20.0"
        ),
    ],
    targets: [
        .target(
            name: "FitnessTraining",
            dependencies: ["FitnessCore", "FitnessStorage", "FitnessAnalytics", "FitnessUI", .product(name: "Factory", package: "Factory")]
        ),
        .target(
            name: "FitnessTrainingTestSupport",
            dependencies: ["FitnessTraining"]
        ),
        .testTarget(
            name: "FitnessTrainingTests",
            dependencies: [
                "FitnessTraining",
                "FitnessTrainingTestSupport",
                "FitnessCore",
                "FitnessAnalytics",
                "FitnessUI",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
