// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessCore", targets: ["FitnessCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Kolos65/Mockable.git", from: "0.6.2"),
    ],
    targets: [
        .target(
            name: "FitnessCore",
            dependencies: [
                .product(name: "Mockable", package: "Mockable"),
            ],
            swiftSettings: [
                .define("MOCKING", .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "FitnessCoreTests",
            dependencies: ["FitnessCore"]
        ),
    ]
)
