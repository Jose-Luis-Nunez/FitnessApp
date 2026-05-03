// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessTestSupport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessTestSupport", targets: ["FitnessTestSupport"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(url: "https://github.com/Kolos65/Mockable.git", from: "0.6.2"),
    ],
    targets: [
        .target(
            name: "FitnessTestSupport",
            dependencies: [
                "FitnessCore",
                .product(name: "Mockable", package: "Mockable"),
            ]
        ),
    ]
)
