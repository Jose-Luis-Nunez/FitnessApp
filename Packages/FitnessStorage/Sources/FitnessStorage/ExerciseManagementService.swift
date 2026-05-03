import Foundation
import FitnessCore
import Factory

@MainActor
public final class ExerciseManagementService: ExerciseManaging {
    private let storageService: ExerciseStoring
    private let analyticsStorage: AnalyticsStoring
    private let workoutStorageService: WorkoutStoring

    public init(
        exerciseStorage: ExerciseStoring? = nil,
        analyticsStorage: AnalyticsStoring? = nil,
        workoutStorage: WorkoutStoring? = nil
    ) {
        self.storageService = exerciseStorage ?? Container.shared.exerciseStorage()
        self.analyticsStorage = analyticsStorage ?? Container.shared.analyticsStorage()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
    }

    public func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        var exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            exercises[index] = updatedExercise
            saveExercises(exercises, workoutId: currentWorkout.id, category: category)
        }
    }

    public func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return [] }
        return storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
    }

    public func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup, atTop: Bool = false) {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }
        var exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)

        if atTop {
            exercises.insert(exercise, at: 0)
        } else {
            exercises.append(exercise)
        }

        saveExercises(exercises, workoutId: currentWorkout.id, category: category)
    }

    public func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress]) {
        var updatedExercise = exercise
        updatedExercise.isCompleted = true
        updateExercise(updatedExercise, category: category)
        saveAnalytics(exerciseId: exercise.id, setProgress: setProgress)
    }

    public func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        var updatedExercise = exercise
        updatedExercise.isCompleted = false
        updateExercise(updatedExercise, category: category)
    }

    public func resetAllExercises(for categories: [MuscleCategoryGroup]) {
        guard let currentWorkout = workoutStorageService.currentWorkout else { return }

        for category in categories {
            let exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
            let updatedExercises = exercises.map { exercise in
                var updatedExercise = exercise
                updatedExercise.isCompleted = false
                return updatedExercise
            }
            saveExercises(updatedExercises, workoutId: currentWorkout.id, category: category)
        }
    }

    public func saveAnalytics(exerciseId: UUID, setProgress: [SetProgress]) {
        guard !setProgress.isEmpty else { return }
        let entry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: Date(),
            setProgress: setProgress
        )
        var entries = analyticsStorage.load(for: exerciseId)
        entries.append(entry)
        analyticsStorage.save(entries, for: exerciseId)
    }

    private func saveExercises(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        storageService.saveForWorkout(exercises, workoutId: workoutId, category: category)
    }

    public func getExerciseCount(for category: MuscleCategoryGroup) -> (total: Int, active: Int) {
        let exercises = getExercises(for: category)
        return (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
    }

    public func getAllExerciseCounts(for categories: [MuscleCategoryGroup]) -> [MuscleCategoryGroup: (total: Int, active: Int)] {
        var counts: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]
        for category in categories {
            counts[category] = getExerciseCount(for: category)
        }
        return counts
    }

    public func hasInactiveExercises(for categories: [MuscleCategoryGroup]) -> Bool {
        for category in categories {
            let exercises = getExercises(for: category)
            if exercises.contains(where: { $0.isCompleted }) {
                return true
            }
        }
        return false
    }
}
