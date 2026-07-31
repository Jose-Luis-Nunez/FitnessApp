import Foundation
import FitnessCore
import Factory
import FitnessStorage

@MainActor
public struct DeleteAnalyticsSetUseCase {
    private enum Target {
        case physicalSet(index: Int)
        case logicalSet(index: Int)
    }

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
    public func execute(
        exerciseId: UUID,
        entryId: UUID,
        setIndex: Int
    ) {
        execute(
            exerciseId: exerciseId,
            entryId: entryId,
            target: .physicalSet(index: setIndex)
        )
    }

    public func execute(
        exerciseId: UUID,
        entryId: UUID,
        logicalSetIndex: Int
    ) {
        execute(
            exerciseId: exerciseId,
            entryId: entryId,
            target: .logicalSet(index: logicalSetIndex)
        )
    }

    private func execute(
        exerciseId: UUID,
        entryId: UUID,
        target: Target
    ) {
        var existingEntries = storageService.load(for: exerciseId)

        guard let entryIndex = existingEntries.firstIndex(where: { $0.id == entryId }) else { return }

        let entry = existingEntries[entryIndex]

        var updatedSetProgress = entry.setProgress
        switch target {
        case .logicalSet(let logicalSetIndex):
            guard updatedSetProgress.contains(where: {
                $0.logicalSetIndex == logicalSetIndex
            }) else {
                return
            }
            updatedSetProgress.removeAll { $0.logicalSetIndex == logicalSetIndex }
        case .physicalSet(let setIndex) where updatedSetProgress.indices.contains(setIndex):
            updatedSetProgress.remove(at: setIndex)
        case .physicalSet:
            return
        }

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
            let exercises = exerciseStorageService.loadForWorkout(
                workoutId: currentWorkout.id,
                category: category
            )

            if var exercise = exercises.first(where: { $0.id == exerciseId }) {
                exercise.isCompleted = isCompleted
                exerciseStorageService.updateExercise(exercise)
                return
            }
        }
    }
}
