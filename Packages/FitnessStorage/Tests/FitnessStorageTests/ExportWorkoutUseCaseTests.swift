import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("ExportWorkoutUseCase", .tags(.integration))
@MainActor
struct ExportWorkoutUseCaseTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private struct SUT {
        let exportUseCase: ExportWorkoutUseCase
        let importUseCase: ImportWorkoutUseCase
        let workoutStorage: WorkoutStorageService
        let exerciseStorage: ExerciseStorageService
        let analyticsStorage: AnalyticsStorageService
        let totalAnalyticsStorage: TotalAnalyticsStorageService
    }

    private func makeSUT() -> SUT {
        let defaults = TestHelpers.makeIsolatedDefaults()
        let es = ExerciseStorageService(container: container)
        let analytics = AnalyticsStorageService(container: container)
        let ws = WorkoutStorageService(
            container: container,
            defaults: defaults,
            exerciseStorage: es,
            analyticsStorage: analytics
        )
        let total = TotalAnalyticsStorageService(
            analyticsStorage: analytics,
            exerciseStorage: es,
            workoutStorage: ws
        )
        let exportUseCase = ExportWorkoutUseCase(
            exerciseStorage: es,
            totalAnalyticsStorage: total
        )
        let importUseCase = ImportWorkoutUseCase(workoutStorage: ws)
        return SUT(
            exportUseCase: exportUseCase,
            importUseCase: importUseCase,
            workoutStorage: ws,
            exerciseStorage: es,
            analyticsStorage: analytics,
            totalAnalyticsStorage: total
        )
    }

    // MARK: - Happy Path

    @Test("export of populated workout produces decodable envelope JSON")
    func exportPopulatedWorkoutDecodes() throws {
        let sut = makeSUT()
        let workout = sut.workoutStorage.createWorkout(name: "Push", selectedCategories: [.chest])
        let exercise = Exercise(name: "Bench", weight: 80, reps: 8, sets: 3, iconName: "defaultArmsIcon", category: .chest)
        sut.exerciseStorage.saveForWorkout([exercise], workoutId: workout.id, category: .chest)
        let entry = AnalyticsEntry(
            exerciseId: exercise.id,
            date: Date(),
            setProgress: [SetProgress(status: .completedDone, currentReps: 8, weight: 80)]
        )
        sut.analyticsStorage.save([entry], for: exercise.id)

        let json = try sut.exportUseCase.execute(workout: workout)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(WorkoutShareEnvelope.self, from: Data(json.utf8))

        #expect(envelope.version == WorkoutShareEnvelope.currentVersion)
        #expect(envelope.workout.name == "Push")
        #expect(envelope.exercises.count == 1)
        #expect(envelope.exercises.first?.name == "Bench")
        #expect(envelope.analytics.count == 1)
        #expect(envelope.analytics.first?.exerciseId == exercise.id)
    }

    @Test("export of workout with exercises across multiple categories includes all")
    func exportMultiCategoryWorkout() throws {
        let sut = makeSUT()
        let workout = sut.workoutStorage.createWorkout(name: "Full Body", selectedCategories: [.arms, .chest, .legs])
        let armEx = Exercise(name: "Curl", weight: 20, reps: 10, sets: 3, iconName: "defaultArmsIcon", category: .arms)
        let chestEx = Exercise(name: "Bench", weight: 80, reps: 8, sets: 3, iconName: "defaultArmsIcon", category: .chest)
        let legsEx = Exercise(name: "Squat", weight: 100, reps: 6, sets: 4, iconName: "defaultArmsIcon", category: .legs)
        sut.exerciseStorage.saveForWorkout([armEx], workoutId: workout.id, category: .arms)
        sut.exerciseStorage.saveForWorkout([chestEx], workoutId: workout.id, category: .chest)
        sut.exerciseStorage.saveForWorkout([legsEx], workoutId: workout.id, category: .legs)

        let json = try sut.exportUseCase.execute(workout: workout)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(WorkoutShareEnvelope.self, from: Data(json.utf8))
        #expect(envelope.exercises.count == 3, "Export must aggregate exercises across all selected categories.")
        #expect(envelope.exercises.contains { $0.name == "Curl" && $0.category == .arms })
        #expect(envelope.exercises.contains { $0.name == "Bench" && $0.category == .chest })
        #expect(envelope.exercises.contains { $0.name == "Squat" && $0.category == .legs })
    }

    @Test("export of empty workout yields empty exercises and analytics arrays")
    func exportEmptyWorkout() throws {
        let sut = makeSUT()
        let workout = sut.workoutStorage.createWorkout(name: "Empty", selectedCategories: [.arms])

        let json = try sut.exportUseCase.execute(workout: workout)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(WorkoutShareEnvelope.self, from: Data(json.utf8))
        #expect(envelope.exercises.isEmpty)
        #expect(envelope.analytics.isEmpty)
    }

    // MARK: - Roundtrip

    @Test("export → import roundtrip preserves exercise data and analytics (modulo new UUIDs)")
    func roundtripPreservesData() throws {
        let sut = makeSUT()
        let workout = sut.workoutStorage.createWorkout(name: "Roundtrip", selectedCategories: [.chest])
        let exercise = Exercise(name: "Press", weight: 100, reps: 5, sets: 5, iconName: "defaultArmsIcon", category: .chest)
        sut.exerciseStorage.saveForWorkout([exercise], workoutId: workout.id, category: .chest)
        let entry = AnalyticsEntry(
            exerciseId: exercise.id,
            date: Date(),
            setProgress: [
                SetProgress(status: .completedDone, currentReps: 5, weight: 100),
                SetProgress(status: .completedDone, currentReps: 5, weight: 100)
            ]
        )
        sut.analyticsStorage.save([entry], for: exercise.id)

        let exportedJson = try sut.exportUseCase.execute(workout: workout)
        let imported = try sut.importUseCase.execute(jsonString: exportedJson)

        let importedExercises = sut.exerciseStorage.loadForWorkout(workoutId: imported.id, category: .chest)
        #expect(importedExercises.count == 1)
        let importedExercise = try #require(importedExercises.first)
        // UUIDs change but content is preserved
        #expect(importedExercise.name == "Press")
        #expect(importedExercise.weight == 100)
        #expect(importedExercise.reps == 5)
        #expect(importedExercise.sets == 5)
        #expect(importedExercise.category == .chest)
        #expect(importedExercise.id != exercise.id, "Import must assign a fresh exercise UUID")

        let importedEntries = sut.analyticsStorage.load(for: importedExercise.id)
        #expect(importedEntries.count == 1)
        let importedEntry = try #require(importedEntries.first)
        #expect(importedEntry.exerciseId == importedExercise.id, "Analytics must be remapped to the new exercise UUID")
        #expect(importedEntry.setProgress.count == 2)
        #expect(importedEntry.setProgress.first?.weight == 100)
    }
}
