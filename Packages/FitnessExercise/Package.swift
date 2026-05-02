// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessExercise",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessExercise", targets: ["FitnessExercise"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessAnalytics"),
        .package(path: "../FitnessTraining"),
        .package(path: "../FitnessUI"),
        .package(path: "../FitnessResources"),
        .package(path: "../FitnessPersistenceUI"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
        .package(path: "../FitnessTestSupport"),
    ],
    targets: [
        .target(
            name: "FitnessExercise",
            dependencies: ["FitnessCore", "FitnessStorage", "FitnessAnalytics", "FitnessTraining", "FitnessUI", "FitnessResources", "FitnessPersistenceUI", .product(name: "Factory", package: "Factory")]
        ),
        .testTarget(
            name: "FitnessExerciseTests",
            dependencies: [
                "FitnessExercise",
                "FitnessCore",
                "FitnessStorage",
                "FitnessTraining",
                "FitnessAnalytics",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ]
        ),
    ]
)
