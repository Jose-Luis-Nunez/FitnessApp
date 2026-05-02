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
    ],
    targets: [
        .target(
            name: "FitnessTestSupport",
            dependencies: [
                "FitnessCore",
            ]
        ),
    ]
)
