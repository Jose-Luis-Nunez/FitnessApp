// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FitnessModules",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnessResources", targets: ["FitnessResources"]),
        .library(name: "FitnessCore", targets: ["FitnessCore"]),
        .library(name: "FitnessStorage", targets: ["FitnessStorage"]),
        .library(name: "FitnessUI", targets: ["FitnessUI"]),
        .library(name: "FitnessAnalytics", targets: ["FitnessAnalytics"]),
        .library(name: "FitnessTraining", targets: ["FitnessTraining"]),
        .library(name: "FitnessTrainingTestSupport", targets: ["FitnessTrainingTestSupport"]),
        .library(name: "FitnessExercise", targets: ["FitnessExercise"]),
        .library(name: "FitnessPersistenceUI", targets: ["FitnessPersistenceUI"]),
        .library(name: "FitnessSchedule", targets: ["FitnessSchedule"]),
        .library(name: "FitnessProfile", targets: ["FitnessProfile"]),
        .library(name: "FitnessWorkouts", targets: ["FitnessWorkouts"]),
        .library(name: "FitnessFriends", targets: ["FitnessFriends"]),
        .library(name: "FitnessTestSupport", targets: ["FitnessTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            "1.19.2"..<"1.20.0"
        ),
    ],
    targets: [
        .plugin(
            name: "GenerateLocalizationAPIPlugin",
            capability: .buildTool(),
            path: "FitnessResources/Plugins/GenerateLocalizationAPIPlugin"
        ),
        .target(
            name: "FitnessResources",
            path: "FitnessResources/Sources/FitnessResources",
            resources: [.process("Resources")],
            plugins: [.plugin(name: "GenerateLocalizationAPIPlugin")]
        ),
        .target(
            name: "FitnessCore",
            path: "FitnessCore/Sources/FitnessCore"
        ),
        .target(
            name: "FitnessStorage",
            dependencies: [
                "FitnessCore",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessStorage/Sources/FitnessStorage"
        ),
        .target(
            name: "FitnessUI",
            dependencies: ["FitnessCore", "FitnessResources"],
            path: "FitnessUI/Sources/FitnessUI"
        ),
        .target(
            name: "FitnessAnalytics",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI",
                "FitnessResources",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessAnalytics/Sources/FitnessAnalytics"
        ),
        .target(
            name: "FitnessTraining",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessAnalytics",
                "FitnessUI",
                "FitnessResources",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessTraining/Sources/FitnessTraining"
        ),
        .target(
            name: "FitnessTrainingTestSupport",
            dependencies: ["FitnessTraining"],
            path: "FitnessTraining/Sources/FitnessTrainingTestSupport"
        ),
        .target(
            name: "FitnessPersistenceUI",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI",
                "FitnessResources",
                "FitnessAnalytics",
                "FitnessTraining",
            ],
            path: "FitnessPersistenceUI/Sources/FitnessPersistenceUI"
        ),
        .target(
            name: "FitnessExercise",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessAnalytics",
                "FitnessTraining",
                "FitnessUI",
                "FitnessResources",
                "FitnessPersistenceUI",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessExercise/Sources/FitnessExercise"
        ),
        .target(
            name: "FitnessSchedule",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessAnalytics",
                "FitnessUI",
                "FitnessResources",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessSchedule/Sources/FitnessSchedule"
        ),
        .target(
            name: "FitnessProfile",
            dependencies: ["FitnessUI", "FitnessResources"],
            path: "FitnessProfile/Sources/FitnessProfile"
        ),
        .target(
            name: "FitnessWorkouts",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI",
                "FitnessResources",
                "FitnessExercise",
                "FitnessAnalytics",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessWorkouts/Sources/FitnessWorkouts"
        ),
        .target(
            name: "FitnessFriends",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI",
                "FitnessResources",
                "FitnessWorkouts",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessFriends/Sources/FitnessFriends"
        ),
        .target(
            name: "FitnessTestSupport",
            dependencies: ["FitnessCore"],
            path: "FitnessTestSupport/Sources/FitnessTestSupport"
        ),
        .target(
            name: "FitnessStorageTestSupport",
            dependencies: ["FitnessStorage", "FitnessCore", "FitnessTestSupport"],
            path: "FitnessStorage/Tests/FitnessStorageTestSupport"
        ),

        .testTarget(
            name: "FitnessResourcesTests",
            dependencies: ["FitnessResources"],
            path: "FitnessResources/Tests/FitnessResourcesTests"
        ),
        .testTarget(
            name: "FitnessCoreTests",
            dependencies: ["FitnessCore", "FitnessTestSupport"],
            path: "FitnessCore/Tests/FitnessCoreTests"
        ),
        .testTarget(
            name: "FitnessStorageTests",
            dependencies: [
                "FitnessStorage",
                "FitnessTestSupport",
                "FitnessStorageTestSupport",
            ],
            path: "FitnessStorage/Tests/FitnessStorageTests",
            exclude: [
                "DataMigrationServiceTests.swift",
                "LegacyMigrationServiceInitOrderingTests.swift",
                "Schema",
            ]
        ),
        .testTarget(
            name: "FitnessStorageMigrationTests",
            dependencies: [
                "FitnessStorage",
                "FitnessTestSupport",
                "FitnessStorageTestSupport",
            ],
            path: "FitnessStorage/Tests/FitnessStorageTests",
            sources: [
                "DataMigrationServiceTests.swift",
                "LegacyMigrationServiceInitOrderingTests.swift",
                "Schema/MigrationV1toV2Tests.swift",
                "Schema/MigrationV2toV3Tests.swift",
                "Schema/MigrationV3toV4Tests.swift",
                "Schema/MigrationV4toV5Tests.swift",
                "Schema/MigrationV5toV6Tests.swift",
                "Schema/ModelContainerBootstrapTests.swift",
            ]
        ),
        .testTarget(
            name: "FitnessUITests",
            dependencies: ["FitnessUI", "FitnessTestSupport"],
            path: "FitnessUI/Tests/FitnessUITests"
        ),
.testTarget(
            name: "FitnessAnalyticsTests",
            dependencies: [
                "FitnessAnalytics",
                "FitnessCore",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessAnalytics/Tests/FitnessAnalyticsTests",
            exclude: ["PerformanceLoadingTests.swift"]
        ),
        .testTarget(
            name: "FitnessAnalyticsIntegrationTests",
            dependencies: [
                "FitnessAnalytics",
                "FitnessCore",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessAnalytics/Tests/FitnessAnalyticsTests",
            sources: ["PerformanceLoadingTests.swift"]
        ),
.testTarget(
            name: "FitnessTrainingTests",
            dependencies: [
                "FitnessTraining",
                "FitnessTrainingTestSupport",
                "FitnessCore",
                "FitnessAnalytics",
                "FitnessUI",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessTraining/Tests/FitnessTrainingTests",
            exclude: [
                "BilateralTrainingSnapshotTests.swift",
                "__Snapshots__",
            ]
        ),
        .testTarget(
            name: "FitnessTrainingSnapshotTests",
            dependencies: [
                "FitnessTraining",
                "FitnessTrainingTestSupport",
                "FitnessCore",
                "FitnessAnalytics",
                "FitnessUI",
                "FitnessTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "FitnessTraining/Tests/FitnessTrainingTests",
            sources: ["BilateralTrainingSnapshotTests.swift"]
        ),
        .testTarget(
            name: "FitnessExerciseTests",
            dependencies: [
                "FitnessExercise",
                "FitnessCore",
                "FitnessStorage",
                "FitnessTraining",
                "FitnessAnalytics",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessExercise/Tests/FitnessExerciseTests",
            exclude: [
                "EnvironmentObjectContractTests.swift",
                "WorkoutScopedExerciseQueryViewTests.swift",
            ]
        ),
.testTarget(
            name: "FitnessExerciseIntegrationTests",
            dependencies: [
                "FitnessExercise",
                "FitnessCore",
                "FitnessStorage",
                "FitnessTestSupport",
            ],
            path: "FitnessExercise/Tests/FitnessExerciseTests",
            sources: [
                "EnvironmentObjectContractTests.swift",
                "WorkoutScopedExerciseQueryViewTests.swift",
            ]
        ),
        .testTarget(
            name: "FitnessPersistenceUIIntegrationTests",
            dependencies: [
                "FitnessPersistenceUI",
                "FitnessStorage",
                "FitnessCore",
                "FitnessTestSupport",
            ],
            path: "FitnessPersistenceUI/Tests/FitnessPersistenceUITests",
            sources: [
                "CardLoadOutcomeStateTests.swift",
                "CategoryTileModelViewTests.swift",
            ]
        ),
        .testTarget(
            name: "FitnessPersistenceUISnapshotTests",
            dependencies: [
                "FitnessPersistenceUI",
                "FitnessStorage",
                "FitnessCore",
                "FitnessAnalytics",
                "FitnessTraining",
                "FitnessUI",
                "FitnessTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "FitnessPersistenceUI/Tests/FitnessPersistenceUITests",
            sources: ["IdleCardSnapshotTests.swift"]
        ),
        .testTarget(
            name: "FitnessScheduleTests",
            dependencies: [
                "FitnessSchedule",
                "FitnessCore",
                "FitnessAnalytics",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessSchedule/Tests/FitnessScheduleTests"
        ),
        .testTarget(
            name: "FitnessProfileTests",
            dependencies: ["FitnessProfile", "FitnessTestSupport"],
            path: "FitnessProfile/Tests/FitnessProfileTests"
        ),
        .testTarget(
            name: "FitnessWorkoutsTests",
            dependencies: [
                "FitnessWorkouts",
                "FitnessCore",
                "FitnessStorage",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessWorkouts/Tests/FitnessWorkoutsTests"
        ),
        .testTarget(
            name: "FitnessFriendsTests",
            dependencies: [
                "FitnessFriends",
                "FitnessCore",
                "FitnessStorage",
                "FitnessTestSupport",
                .product(name: "Factory", package: "Factory"),
            ],
            path: "FitnessFriends/Tests/FitnessFriendsTests"
        ),
    ]
)
