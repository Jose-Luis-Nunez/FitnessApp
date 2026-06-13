// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessPersistenceUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessPersistenceUI", targets: ["FitnessPersistenceUI"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessUI"),
        .package(path: "../FitnessAnalytics"),
        .package(path: "../FitnessTraining"),
        .package(path: "../FitnessTestSupport"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", "1.19.2"..<"1.20.0"),
    ],
    targets: [
        .target(
            name: "FitnessPersistenceUI",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI",
                "FitnessAnalytics",
                "FitnessTraining",
            ]
        ),
        .testTarget(
            name: "FitnessPersistenceUITests",
            dependencies: [
                "FitnessPersistenceUI",
                "FitnessStorage",
                "FitnessCore",
                "FitnessAnalytics",
                "FitnessTraining",
                "FitnessUI",
                "FitnessTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
