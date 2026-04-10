// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessUI", targets: ["FitnessUI"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessResources"),
        .package(path: "../FitnessStorage"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "FitnessUI",
            dependencies: ["FitnessCore", "FitnessResources", "FitnessStorage", .product(name: "Factory", package: "Factory")]
        ),
        .testTarget(
            name: "FitnessUITests",
            dependencies: ["FitnessUI"]
        ),
    ]
)
