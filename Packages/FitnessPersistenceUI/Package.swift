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
                "FitnessTestSupport",
            ]
        ),
    ]
)
