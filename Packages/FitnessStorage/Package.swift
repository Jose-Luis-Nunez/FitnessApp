// swift-tools-version: 5.9

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
    ],
    targets: [
        .target(
            name: "FitnessStorage",
            dependencies: ["FitnessCore", .product(name: "Factory", package: "Factory")]
        ),
        .testTarget(
            name: "FitnessStorageTests",
            dependencies: ["FitnessStorage", "FitnessTestSupport"]
        ),
    ]
)
