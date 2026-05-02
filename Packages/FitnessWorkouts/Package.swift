// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessWorkouts",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessWorkouts", targets: ["FitnessWorkouts"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessUI"),
        .package(path: "../FitnessExercise"),
        .package(path: "../FitnessTestSupport"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "FitnessWorkouts",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI",
                "FitnessExercise",
                .product(name: "Factory", package: "Factory"),
            ]
        ),
        .testTarget(
            name: "FitnessWorkoutsTests",
            dependencies: [
                "FitnessWorkouts",
                "FitnessCore",
                "FitnessStorage",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ]
        ),
    ]
)
