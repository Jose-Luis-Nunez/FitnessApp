// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessProfile",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessProfile", targets: ["FitnessProfile"]),
    ],
    dependencies: [
        .package(path: "../FitnessUI"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "FitnessProfile",
            dependencies: ["FitnessUI"]
        ),
        .testTarget(
            name: "FitnessProfileTests",
            dependencies: [
                "FitnessProfile",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
