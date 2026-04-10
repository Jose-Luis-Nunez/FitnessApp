// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessTraining",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessTraining", targets: ["FitnessTraining"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessAnalytics"),
        .package(path: "../FitnessUI"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.0.0"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "FitnessTraining",
            dependencies: ["FitnessCore", "FitnessStorage", "FitnessAnalytics", "FitnessUI", .product(name: "Factory", package: "Factory")]
        ),
        .testTarget(
            name: "FitnessTrainingTests",
            dependencies: [
                "FitnessTraining",
                "FitnessCore",
                "FitnessAnalytics",
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Factory", package: "Factory"),
            ]
        ),
    ]
)
