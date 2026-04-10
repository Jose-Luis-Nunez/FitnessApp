// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessSchedule",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessSchedule", targets: ["FitnessSchedule"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessAnalytics"),
        .package(path: "../FitnessUI"),
    ],
    targets: [
        .target(
            name: "FitnessSchedule",
            dependencies: ["FitnessCore", "FitnessStorage", "FitnessAnalytics", "FitnessUI"]
        ),
        .testTarget(
            name: "FitnessScheduleTests",
            dependencies: ["FitnessSchedule"]
        ),
    ]
)
