import Testing
import Foundation
import SwiftData
import FitnessCore
import Mockable
@_spi(PersistenceUI) @testable import FitnessStorage

/// Pins the ordering contract between the legacy JSON → SwiftData import
/// (`DataMigrationService`) and `WorkoutStorageService.init`.
///
/// The contract: by the time `WorkoutStorageService.init` runs against a given
/// `ModelContainer`, the legacy import for that container MUST already have
/// completed. If the order is reversed, the service observes an empty store,
/// seeds an auto-default `Workout 1`, and writes its id to UserDefaults — and
/// the subsequent import lands a set of "real" workouts that are now hidden
/// behind the auto-default seed.
///
/// Two paths cover the contract:
///   - **prevention** (`migrationBeforeServiceInitProducesCleanState`):
///     migration first → service second produces the desired state with no
///     auto-default and `current_workout_id` pointing at the imported workout.
///   - **cure** (`brokenOrderIsHealedOnNextLaunch`): forces the broken order
///     and asserts that the next service init heals the corruption via
///     `WorkoutStorageService.healInheritedAutoDefaultIfNeeded`.
///
/// Production guarantees the prevention path by running
/// `DataMigrationService.migrateIfNeeded` inside
/// `ModelContainerBootstrap.makeProductionContainer()` before the container is
/// returned. The cure path remains as a defence for installs whose first
/// post-fix launch inherited a broken state from a prior pre-fix launch.
@Suite("Legacy migration / service init ordering contract", .serialized)
@MainActor
struct LegacyMigrationServiceInitOrderingTests {

    private func makeIsolatedDocuments() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "LegacyMigrationOrdering-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Plants the legacy JSON shape pre-T3 phones had: a workouts blob in
    /// UserDefaults plus per-(workout, category) exercise JSONs in Documents.
    private func plantLegacyData(in docsDir: URL, defaults: UserDefaults, userId: String) -> (workoutId: UUID, exerciseName: String) {
        let workoutId = UUID()
        let workout = Workout(
            id: workoutId,
            name: "Holmes Place",
            createdDate: Date(timeIntervalSinceNow: -86_400 * 365),
            lastModified: Date(timeIntervalSinceNow: -86_400 * 30),
            selectedCategories: [.arms]
        )

        let workouts = [workout]
        defaults.set(try! JSONEncoder().encode(workouts), forKey: "stored_workouts")
        defaults.set(userId, forKey: "userId")
        defaults.set(workoutId.uuidString, forKey: "current_workout_id")
        defaults.set(workoutId.uuidString, forKey: "default_workout_id")

        let exerciseName = "Stange ziehen"
        let exercise = Exercise(
            name: exerciseName, weight: 30, reps: 10, sets: 3,
            iconName: "arm", category: .arms
        )
        let exerciseFile = docsDir.appendingPathComponent("workout_\(workoutId.uuidString)_arms_\(userId).json")
        try! JSONEncoder().encode([exercise]).write(to: exerciseFile)

        return (workoutId, exerciseName)
    }

    @Test("Prevention: migration runs before service init → no auto-default seeded next to imports")
    func migrationBeforeServiceInitProducesCleanState() throws {
        let docsDir = makeIsolatedDocuments()
        defer { cleanup(docsDir) }
        let defaults = TestHelpers.makeIsolatedDefaults()
        let userId = UUID().uuidString
        let (legacyWorkoutId, _) = plantLegacyData(in: docsDir, defaults: defaults, userId: userId)

        let container = TestHelpers.makeInMemoryContainer()
        DataMigrationService.migrateIfNeeded(context: container.mainContext, defaults: defaults, documentsDir: docsDir)
        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring())

        #expect(sut.workouts.count == 1, "Only the imported legacy workout must exist; no auto-default should be seeded.")
        #expect(sut.workouts.first?.id == legacyWorkoutId, "The imported workout must be the surviving one.")
        #expect(sut.currentWorkout?.id == legacyWorkoutId, "current_workout_id must point at the legacy workout.")
        #expect(defaults.string(forKey: "current_workout_id") == legacyWorkoutId.uuidString)
    }

    @Test("Cure: install that booted in the broken order is healed by the service on next launch")
    func brokenOrderIsHealedOnNextLaunch() throws {
        let docsDir = makeIsolatedDocuments()
        defer { cleanup(docsDir) }
        let defaults = TestHelpers.makeIsolatedDefaults()
        let userId = UUID().uuidString
        let (legacyWorkoutId, _) = plantLegacyData(in: docsDir, defaults: defaults, userId: userId)

        let container = TestHelpers.makeInMemoryContainer()

        let firstService = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring())
        let autoSeedId = try #require(firstService.workouts.first?.id)
        #expect(firstService.workouts.first?.name == "Workout 1")
        #expect(defaults.string(forKey: "current_workout_id") == autoSeedId.uuidString)

        DataMigrationService.migrateIfNeeded(context: container.mainContext, defaults: defaults, documentsDir: docsDir)

        let secondService = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring())

        #expect(secondService.workouts.count == 1, "Heal pass must remove the empty auto-default that was seeded before the import.")
        #expect(secondService.workouts.first?.id == legacyWorkoutId)
        #expect(secondService.currentWorkout?.id == legacyWorkoutId, "current_workout_id must be repointed to the real workout.")
        #expect(secondService.defaultWorkout?.id == legacyWorkoutId)
        #expect(defaults.string(forKey: "current_workout_id") == legacyWorkoutId.uuidString)
        #expect(defaults.string(forKey: "default_workout_id") == legacyWorkoutId.uuidString)
    }
}
