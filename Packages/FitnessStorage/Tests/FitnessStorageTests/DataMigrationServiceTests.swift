import Testing
import Foundation
import SwiftData
import FitnessCore
@_spi(PersistenceUI) @testable import FitnessStorage
import Factory

@Suite("DataMigrationService")
@MainActor
struct DataMigrationServiceTests {

    private let migrationKey = "swiftdata_migration_complete"
    private let workoutsKey = "stored_workouts"
    private let currentWorkoutKey = "current_workout_id"
    private let defaultWorkoutKey = "default_workout_id"
    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeContext() -> ModelContext {
        ModelContext(container)
    }

    // MARK: - Migration Flag

    @Test func skipsWhenMigrationAlreadyComplete() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        defaults.set(true, forKey: migrationKey)

        let context = makeContext()
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults)

        let workouts = (try? context.fetch(FetchDescriptor<WorkoutModel>())) ?? []
        #expect(workouts.isEmpty)
    }

    @Test func setsCompleteFlagWhenNoLegacyData() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let tempDir = TestHelpers.makeTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }

        let context = makeContext()
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)

        #expect(defaults.bool(forKey: migrationKey) == true)
    }

    // MARK: - Workout Migration

    @Test func migratesLegacyWorkoutsFromUserDefaults() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let tempDir = TestHelpers.makeTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }

        let workout1 = Workout(name: "Push Day", selectedCategories: [.chest, .arms])
        let workout2 = Workout(name: "Pull Day", selectedCategories: [.back])

        let data = try! JSONEncoder().encode([workout1, workout2])
        defaults.set(data, forKey: workoutsKey)
        defaults.set(workout1.id.uuidString, forKey: currentWorkoutKey)
        defaults.set(workout2.id.uuidString, forKey: defaultWorkoutKey)

        let context = makeContext()
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)

        let models = (try? context.fetch(FetchDescriptor<WorkoutModel>())) ?? []
        #expect(models.contains { $0.id == workout1.id }, "Push Day should be migrated")
        #expect(models.contains { $0.id == workout2.id }, "Pull Day should be migrated")

        let push = models.first { $0.id == workout1.id }
        #expect(push?.name == "Push Day")
        #expect(push?.selectedCategories.count == 2)

        let pull = models.first { $0.id == workout2.id }
        #expect(pull?.isDefault == true)

        #expect(defaults.bool(forKey: migrationKey) == true)
    }

    // MARK: - Exercise Migration via Files

    @Test func migratesLegacyExerciseFiles() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let tempDir = TestHelpers.makeTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }

        let workout = Workout(name: "Test Workout")
        let workoutData = try! JSONEncoder().encode([workout])
        defaults.set(workoutData, forKey: workoutsKey)
        defaults.set("testuser", forKey: "userId")

        let exercise = Exercise(
            name: "Barbell Curl",
            weight: 30,
            reps: 10,
            sets: 3,
            seatSetting: "2",
            iconName: "defaultArmsIcon",
            category: .arms,
            goal: 40
        )

        let fileName = "workout_\(workout.id.uuidString)_arms_testuser.json"
        let filePath = tempDir.appendingPathComponent(fileName)
        let exerciseData = try! JSONEncoder().encode([exercise])
        try! exerciseData.write(to: filePath)

        let context = makeContext()
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)

        let exerciseModels = (try? context.fetch(FetchDescriptor<ExerciseModel>())) ?? []
        #expect(exerciseModels.count >= 1)

        guard let migrated = exerciseModels.first(where: { $0.name == "Barbell Curl" }) else {
            Issue.record("Barbell Curl not found in migrated exercises")
            return
        }
        #expect(migrated.name == "Barbell Curl")
        #expect(migrated.weight == 30)
        #expect(migrated.reps == 10)
        #expect(migrated.sets == 3)
        #expect(migrated.seatSetting == "2")
        #expect(migrated.category == "arms")
        #expect(migrated.goal == 40)
        #expect(migrated.workout?.id == workout.id)
    }

    // MARK: - Analytics Migration

    @Test func migratesLegacyAnalyticsFiles() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let tempDir = TestHelpers.makeTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }

        let workout = Workout(name: "Test Workout")
        let workoutData = try! JSONEncoder().encode([workout])
        defaults.set(workoutData, forKey: workoutsKey)
        defaults.set("testuser", forKey: "userId")

        let exerciseId = UUID()
        let exercise = Exercise(
            id: exerciseId,
            name: "Curl",
            weight: 20,
            reps: 10,
            sets: 3,
            iconName: "defaultArmsIcon",
            category: .arms
        )

        let exerciseFileName = "workout_\(workout.id.uuidString)_arms_testuser.json"
        let exerciseFile = tempDir.appendingPathComponent(exerciseFileName)
        try! JSONEncoder().encode([exercise]).write(to: exerciseFile)

        let entry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date(),
            setProgress: [
                SetProgress(status: .completedDone, currentReps: 10, weight: 20),
                SetProgress(status: .completedMore, currentReps: 12, weight: 20)
            ]
        )

        let analyticsFileName = "analytics_\(exerciseId)_testuser.json"
        let analyticsFile = tempDir.appendingPathComponent(analyticsFileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode([entry]).write(to: analyticsFile)

        let context = makeContext()
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)

        let analyticsModels = (try? context.fetch(FetchDescriptor<AnalyticsEntryModel>())) ?? []
        #expect(analyticsModels.count == 1)

        let migratedEntry = analyticsModels.first!
        #expect(migratedEntry.exerciseId == exerciseId)
        #expect(migratedEntry.setProgressEntries.count == 2)
    }

    // MARK: - Edge Cases

    @Test func corruptWorkoutDataDoesNotCrash() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let tempDir = TestHelpers.makeTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }

        let context = makeContext()
        let countBefore = (try? context.fetch(FetchDescriptor<WorkoutModel>()))?.count ?? 0

        defaults.set(Data("not json".utf8), forKey: workoutsKey)
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)

        #expect(defaults.bool(forKey: migrationKey) == true)

        let countAfter = (try? context.fetch(FetchDescriptor<WorkoutModel>()))?.count ?? 0
        #expect(countAfter == countBefore, "Corrupt data should not create new workouts")
    }

    @Test func migrationIsIdempotent() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let tempDir = TestHelpers.makeTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }

        let workout = Workout(name: "Test")
        let data = try! JSONEncoder().encode([workout])
        defaults.set(data, forKey: workoutsKey)

        let context = makeContext()
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)
        #expect(defaults.bool(forKey: migrationKey) == true)

        defaults.removeObject(forKey: migrationKey)
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)

        let models = (try? context.fetch(FetchDescriptor<WorkoutModel>())) ?? []
        #expect(models.count >= 1)
    }

    @Test func emptyWorkoutArrayStillSetsMigrationFlag() {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let tempDir = TestHelpers.makeTempDirectory()
        defer { TestHelpers.cleanupTempDirectory(tempDir) }

        let data = try! JSONEncoder().encode([Workout]())
        defaults.set(data, forKey: workoutsKey)

        let context = makeContext()
        DataMigrationService.migrateIfNeeded(context: context, defaults: defaults, documentsDir: tempDir)

        #expect(defaults.bool(forKey: migrationKey) == true)
    }
}
