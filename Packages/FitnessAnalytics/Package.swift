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
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
        .package(path: "../FitnessTestSupport"),
    ],
    targets: [
        .target(
            name: "FitnessAnalytics",
            dependencies: ["FitnessCore", "FitnessStorage", "FitnessUI", .product(name: "Factory", package: "Factory")]
        ),
        .testTarget(
            name: "FitnessAnalyticsTests",
            dependencies: [
                "FitnessAnalytics",
                "FitnessCore",
                "FitnessTestSupport",
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Factory", package: "Factory"),
            ]
        ),
    ]
)
