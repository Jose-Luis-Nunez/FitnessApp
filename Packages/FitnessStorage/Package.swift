// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessStorage",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessStorage", targets: ["FitnessStorage"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessTestSupport"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
        .package(url: "https://github.com/Kolos65/Mockable.git", from: "0.6.2"),
    ],
    targets: [
        .target(
            name: "FitnessStorage",
            dependencies: ["FitnessCore", .product(name: "Factory", package: "Factory")]
        ),
        .testTarget(
            name: "FitnessStorageTests",
            dependencies: [
                "FitnessStorage",
                "FitnessTestSupport",
                .product(name: "Mockable", package: "Mockable"),
            ]
        ),
    ]
)
