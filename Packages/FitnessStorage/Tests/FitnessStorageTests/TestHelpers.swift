import Foundation
import SwiftData
import FitnessCore
import Mockable
@_spi(PersistenceUI) @testable import FitnessStorage

@MainActor
enum TestHelpers {
    private static let testSuiteName = "com.fitnessapp.tests"

    static func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            AnalyticsEntryModel.self,
            SetProgressModel.self,
            ExerciseFeedbackModel.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: config
        )
    }

    static func makeInMemoryContainerWithFriends() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            AnalyticsEntryModel.self,
            SetProgressModel.self,
            ExerciseFeedbackModel.self,
            FriendModel.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: config
        )
    }

    static func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "\(testSuiteName).\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    static func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FitnessTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cleanupTempDirectory(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    static func makeExercise(
        name: String = "Bench Press",
        weight: Double = 60,
        reps: Int = 10,
        sets: Int = 3,
        seatSetting: String? = nil,
        noSeats: Bool = false,
        isCompleted: Bool = false,
        category: MuscleCategoryGroup = .chest,
        iconName: String? = nil,
        goal: Double? = nil
    ) -> Exercise {
        let icon = iconName ?? category.defaultIconName
        return Exercise(
            name: name, weight: weight, reps: reps, sets: sets,
            seatSetting: seatSetting, noSeats: noSeats, isCompleted: isCompleted,
            iconName: icon, category: category, goal: goal
        )
    }

    static func makeNoOpExerciseStoring() -> MockExerciseStoring {
        let mock = MockExerciseStoring(policy: .relaxedVoid)
        given(mock).loadForWorkout(workoutId: .any, category: .any).willReturn([])
        return mock
    }

    static func makeNoOpAnalyticsStoring() -> MockAnalyticsStoring {
        let mock = MockAnalyticsStoring(policy: .relaxedVoid)
        given(mock).load(for: .any).willReturn([])
        return mock
    }

    static func makeWorkoutStorageService(
        container: ModelContainer,
        defaults: UserDefaults? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        analyticsStorage: AnalyticsStoring? = nil
    ) -> WorkoutStorageService {
        WorkoutStorageService(
            container: container,
            defaults: defaults ?? makeIsolatedDefaults(),
            exerciseStorage: exerciseStorage ?? makeNoOpExerciseStoring(),
            analyticsStorage: analyticsStorage ?? makeNoOpAnalyticsStoring()
        )
    }

    @MainActor
    static func makeStorageStack(container: ModelContainer) -> (
        management: ExerciseManagementService,
        workoutStorage: WorkoutStorageService,
        exerciseStorage: ExerciseStorageService,
        analyticsStorage: AnalyticsStorageService
    ) {
        let defaults = makeIsolatedDefaults()
        let exerciseStorage = ExerciseStorageService(container: container)
        let analyticsStorage = AnalyticsStorageService(container: container)
        let workoutStorage = WorkoutStorageService(
            container: container,
            defaults: defaults,
            exerciseStorage: exerciseStorage,
            analyticsStorage: analyticsStorage
        )

        let management = ExerciseManagementService(
            exerciseStorage: exerciseStorage,
            analyticsStorage: analyticsStorage,
            workoutStorage: workoutStorage
        )
        return (management, workoutStorage, exerciseStorage, analyticsStorage)
    }

    static func makeAnalyticsEntry(
        exerciseId: UUID,
        date: Date = Date(),
        setProgress: [SetProgress] = [
            SetProgress(status: .completedDone, currentReps: 10, weight: 60),
            SetProgress(status: .completedMore, currentReps: 12, weight: 60),
            SetProgress(status: .completedLess, currentReps: 8, weight: 60)
        ]
    ) -> AnalyticsEntry {
        AnalyticsEntry(exerciseId: exerciseId, date: date, setProgress: setProgress)
    }
}
