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
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "FitnessTestSupport",
            dependencies: [
                "FitnessCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
