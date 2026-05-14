import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("ImportWorkoutUseCase", .tags(.integration))
@MainActor
struct ImportWorkoutUseCaseTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (ImportWorkoutUseCase, WorkoutStorageService, ExerciseStorageService, AnalyticsStorageService) {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let es = ExerciseStorageService(container: container)
        let as_ = AnalyticsStorageService(container: container)
        let ws = WorkoutStorageService(
            container: container,
            defaults: defaults,
            exerciseStorage: es,
            analyticsStorage: as_
        )
        let sut = ImportWorkoutUseCase(workoutStorage: ws)
        return (sut, ws, es, as_)
    }

    private func makeEnvelopeJSON(
        version: Int = WorkoutShareEnvelope.currentVersion,
        workoutName: String = "Push Day",
        exerciseCount: Int = 2,
        analyticsCount: Int = 3
    ) throws -> (jsonString: String, exerciseIds: [UUID]) {
        let workout = Workout(name: workoutName, selectedCategories: [.chest])
        let exercises: [Exercise] = (0..<exerciseCount).map { i in
            Exercise(
                id: UUID(),
                name: "Exercise \(i)",
                weight: 60 + Double(i * 10),
                reps: 8,
                sets: 3,
                iconName: "defaultArmsIcon",
                category: .chest
            )
        }
        let exerciseIds = exercises.map(\.id)
        let analytics: [AnalyticsEntry] = (0..<analyticsCount).flatMap { i in
            exercises.map { exercise in
                AnalyticsEntry(
                    exerciseId: exercise.id,
                    date: Date().addingTimeInterval(Double(i) * -86400),
                    setProgress: [
                        SetProgress(status: .completedDone, currentReps: 8, weight: exercise.weight)
                    ]
                )
            }
        }
        let envelope = WorkoutShareEnvelope(
            version: version,
            workout: workout,
            exercises: exercises,
            analytics: analytics
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        return (String(data: data, encoding: .utf8)!, exerciseIds)
    }

    // MARK: - Happy Path

    @Test("valid JSON imports cleanly")
    func validJsonImports() throws {
        let (sut, ws, _, _) = makeSUT()
        let countBefore = ws.workouts.count
        let (json, _) = try makeEnvelopeJSON()

        let imported = try sut.execute(jsonString: json)

        #expect(ws.workouts.count == countBefore + 1)
        #expect(imported.name == "Push Day")
        #expect(imported.selectedCategories.contains(.chest))
    }

    // MARK: - UUID freshness

    @Test("imported workout, exercises, and analytics all get fresh UUIDs")
    func freshUUIDsAssigned() throws {
        let (sut, _, es, as_) = makeSUT()
        let (json, sourceExerciseIds) = try makeEnvelopeJSON(exerciseCount: 2, analyticsCount: 2)

        let imported = try sut.execute(jsonString: json)
        let loadedExercises = es.loadForWorkout(workoutId: imported.id, category: .chest)

        // Workout id must differ from anything sourced
        #expect(!sourceExerciseIds.contains(imported.id))
        // Exercise ids must differ from envelope ids
        for exercise in loadedExercises {
            #expect(!sourceExerciseIds.contains(exercise.id))
        }
        // Analytics ids must differ AND exerciseId must point to new exercises
        let newExerciseIds = Set(loadedExercises.map(\.id))
        for exercise in loadedExercises {
            let entries = as_.load(for: exercise.id)
            #expect(!entries.isEmpty)
            for entry in entries {
                #expect(newExerciseIds.contains(entry.exerciseId))
                #expect(!sourceExerciseIds.contains(entry.id))
            }
        }
    }

    // MARK: - Name Collision

    @Test("name collision appends ' (imported)' suffix and never overwrites")
    func nameCollisionAddsSuffix() throws {
        let (sut, ws, _, _) = makeSUT()
        let originalCount = ws.workouts.count
        let collidingName = ws.workouts.first?.name ?? "Workout 1"

        let (json, _) = try makeEnvelopeJSON(workoutName: collidingName)
        let imported = try sut.execute(jsonString: json)

        #expect(imported.name == "\(collidingName) (imported)")
        #expect(ws.workouts.count == originalCount + 1)
        // Original workout untouched
        #expect(ws.workouts.contains(where: { $0.name == collidingName }))
    }

    @Test("second import with same name uses ' (imported 2)' suffix")
    func secondImportUsesNumericSuffix() throws {
        let (sut, ws, _, _) = makeSUT()
        let collidingName = ws.workouts.first?.name ?? "Workout 1"

        let (json, _) = try makeEnvelopeJSON(workoutName: collidingName)
        _ = try sut.execute(jsonString: json)

        let (json2, _) = try makeEnvelopeJSON(workoutName: collidingName)
        let secondImport = try sut.execute(jsonString: json2)

        #expect(secondImport.name == "\(collidingName) (imported 2)")
    }

    // MARK: - Error Paths

    @Test("invalid JSON throws .invalidJSON")
    func invalidJsonThrows() {
        let (sut, _, _, _) = makeSUT()

        #expect(throws: WorkoutShareError.invalidJSON) {
            try sut.execute(jsonString: "not actually json {")
        }
    }

    @Test("higher version throws .unsupportedVersion")
    func higherVersionThrows() throws {
        let (sut, _, _, _) = makeSUT()
        let (json, _) = try makeEnvelopeJSON(version: 99)

        #expect(throws: WorkoutShareError.unsupportedVersion(99)) {
            try sut.execute(jsonString: json)
        }
    }

    @Test("version below 1 throws .unsupportedVersion")
    func zeroVersionThrows() throws {
        let (sut, _, _, _) = makeSUT()
        let (json, _) = try makeEnvelopeJSON(version: 0)

        #expect(throws: WorkoutShareError.unsupportedVersion(0)) {
            try sut.execute(jsonString: json)
        }
    }

    // MARK: - Orphan Analytics

    @Test("orphan analytics entries (exerciseId not in envelope) are silently dropped")
    func orphanAnalyticsDropped() throws {
        let (sut, _, es, as_) = makeSUT()
        let workout = Workout(name: "WithOrphan", selectedCategories: [.chest])
        let exercise = Exercise(
            id: UUID(),
            name: "Bench",
            weight: 80,
            reps: 8,
            sets: 3,
            iconName: "defaultArmsIcon",
            category: .chest
        )
        let validEntry = AnalyticsEntry(
            exerciseId: exercise.id,
            date: Date(),
            setProgress: [SetProgress(status: .completedDone, currentReps: 8, weight: 80)]
        )
        let orphanEntry = AnalyticsEntry(
            exerciseId: UUID(), // exerciseId not in envelope.exercises
            date: Date(),
            setProgress: [SetProgress(status: .completedDone, currentReps: 8, weight: 80)]
        )
        let envelope = WorkoutShareEnvelope(
            workout: workout,
            exercises: [exercise],
            analytics: [validEntry, orphanEntry]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(data: try encoder.encode(envelope), encoding: .utf8)!

        let imported = try sut.execute(jsonString: json)
        let loaded = es.loadForWorkout(workoutId: imported.id, category: .chest)
        let importedExercise = try #require(loaded.first)
        let entries = as_.load(for: importedExercise.id)
        #expect(entries.count == 1, "Orphan should have been dropped; only the valid entry should persist.")
    }

    // MARK: - SelectedCategories Auto-Expand

    @Test("imported exercise categories auto-expand workout.selectedCategories")
    func categoriesAutoExpand() throws {
        let (sut, _, _, _) = makeSUT()
        // Workout declares only .chest, but envelope contains an .arms exercise.
        let workout = Workout(name: "Mismatch", selectedCategories: [.chest])
        let chestExercise = Exercise(id: UUID(), name: "Bench", weight: 80, reps: 8, sets: 3, iconName: "defaultArmsIcon", category: .chest)
        let armExercise = Exercise(id: UUID(), name: "Curl", weight: 20, reps: 10, sets: 3, iconName: "defaultArmsIcon", category: .arms)
        let envelope = WorkoutShareEnvelope(
            workout: workout,
            exercises: [chestExercise, armExercise],
            analytics: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(data: try encoder.encode(envelope), encoding: .utf8)!

        let imported = try sut.execute(jsonString: json)
        #expect(imported.selectedCategories.contains(.chest))
        #expect(imported.selectedCategories.contains(.arms))
    }
}
