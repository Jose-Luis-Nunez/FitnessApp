// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FitnessFriends",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessFriends", targets: ["FitnessFriends"]),
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessUI"),
        .package(path: "../FitnessWorkouts"),
        .package(path: "../FitnessTestSupport"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "FitnessFriends",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI",
                "FitnessWorkouts",
                .product(name: "Factory", package: "Factory"),
            ]
        ),
        .testTarget(
            name: "FitnessFriendsTests",
            dependencies: [
                "FitnessFriends",
                "FitnessCore",
                "FitnessStorage",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ]
        ),
    ]
)
