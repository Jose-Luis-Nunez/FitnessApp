// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessAnalytics",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessAnalytics", targets: ["FitnessAnalytics"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessUI"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "FitnessAnalytics",
            dependencies: ["FitnessCore", "FitnessStorage", "FitnessUI"]
        ),
        .testTarget(
            name: "FitnessAnalyticsTests",
            dependencies: [
                "FitnessAnalytics",
                "FitnessCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
