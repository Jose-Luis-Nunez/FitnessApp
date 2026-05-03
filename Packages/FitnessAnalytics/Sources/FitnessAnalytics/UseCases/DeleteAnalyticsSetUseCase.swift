import Foundation
import FitnessCore
import Factory
import FitnessStorage

@MainActor
public struct DeleteAnalyticsSetUseCase {
    private let storageService: AnalyticsStoring
    private let exerciseStorageService: ExerciseStoring
    private let workoutStorageService: WorkoutStoring

    public init(
        analyticsStorage: AnalyticsStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        workoutStorage: WorkoutStoring? = nil
    ) {
        self.storageService = analyticsStorage ?? Container.shared.analyticsStorage()
        self.exerciseStorageService = exerciseStorage ?? Container.shared.exerciseStorage()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
    }

    /// Removes a set from an analytics entry. Removes the entry entirely if no sets remain.
    /// Updates the exercise completion status when all entries for the exercise are deleted.
    public func execute(exerciseId: UUID, entryId: UUID, setIndex: Int) {
        var existingEntries = storageService.load(for: exerciseId)

        guard let entryIndex = existingEntries.firstIndex(where: { $0.id == entryId }) else { return }

        let entry = existingEntries[entryIndex]
        guard setIndex < entry.setProgress.count else { return }

        var updatedSetProgress = entry.setProgress
        updatedSetProgress.remove(at: setIndex)

        if updatedSetProgress.isEmpty {
            existingEntries.remove(at: entryIndex)
        } else {
            let updatedEntry = AnalyticsEntry(
                id: entry.id,
                exerciseId: entry.exerciseId,
                date: entry.date,
                setProgress: updatedSetProgress
            )
            existingEntries[entryIndex] = updatedEntry
        }

        storageService.save(existingEntries, for: exerciseId)

        if existingEntries.isEmpty {
            updateExerciseCompletionStatus(exerciseId: exerciseId, isCompleted: false)
        }
    }

    private func updateExerciseCompletionStatus(exerciseId: UUID, isCompleted: Bool) {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }

        for category in MuscleCategoryGroup.allCases {
            var exercises = exerciseStorageService.loadForWorkout(workoutId: currentWorkout.id, category: category)

            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) {
                exercises[exerciseIndex].isCompleted = isCompleted
                exerciseStorageService.saveForWorkout(exercises, workoutId: currentWorkout.id, category: category)
                return
            }
        }
    }
}
