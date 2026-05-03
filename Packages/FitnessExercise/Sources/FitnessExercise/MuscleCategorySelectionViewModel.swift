import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessTraining
import Factory

private final class CheckedContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?
    private var cancelledBeforeStore = false

    func store(_ c: CheckedContinuation<Bool, Never>) {
        lock.lock()
        if cancelledBeforeStore {
            lock.unlock()
            c.resume(returning: true)
        } else {
            continuation = c
            lock.unlock()
        }
    }

    func resume(returning value: Bool) {
        lock.lock()
        let c = continuation
        continuation = nil
        if c == nil && value == true {
            cancelledBeforeStore = true
        }
        lock.unlock()
        c?.resume(returning: value)
    }
}

@Observable
@MainActor
public final class MuscleCategorySelectionViewModel {
    /// Tile-grid + cache key set. Product decision: the overview always shows
    /// **all** muscle categories regardless of `Workout.selectedCategories` —
    /// users add exercises freely from the per-category menu, and a "hidden"
    /// category would silently drop those exercises from the overview while
    /// still showing them in list-mode (where the @Query has no category
    /// filter). Keeping this as `allCases` makes the two view modes
    /// consistent and removes a class of bug entirely.
    /// `Workout.selectedCategories` survives at the persistence layer but no
    /// longer drives any UI surface here.
    public let categories: [MuscleCategoryGroup] = MuscleCategoryGroup.allCases
        .sorted { $0.rawValue < $1.rawValue }
    public var exercisesByCategory: [MuscleCategoryGroup: [Exercise]] = [:]

    @ObservationIgnored private var exerciseManagementService: ExerciseManaging
    @ObservationIgnored private var workoutStorageService: WorkoutStoring

    private var exerciseCounts: [MuscleCategoryGroup: (total: Int, active: Int)] {
        exercisesByCategory.mapValues { exercises in
            (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
        }
    }

    nonisolated(unsafe) private var workoutObservationTask: Task<Void, Never>?

    @ObservationIgnored private let coordinatorCache: TrainingCoordinatorCaching
    @ObservationIgnored private let resetAllExercisesUseCase: ResetAllExercisesUseCase

    public init(
        coordinatorCache: TrainingCoordinatorCaching? = nil,
        exerciseManagement: ExerciseManaging? = nil,
        workoutStorage: WorkoutStoring? = nil,
        resetAllExercisesUseCase: ResetAllExercisesUseCase? = nil
    ) {
        self.coordinatorCache = coordinatorCache ?? Container.shared.trainingCoordinatorCache()
        self.exerciseManagementService = exerciseManagement ?? Container.shared.exerciseManagement()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
        self.resetAllExercisesUseCase = resetAllExercisesUseCase ?? Container.shared.resetAllExercisesUseCase()
        refreshExercises()
        startWorkoutObservation()
    }

    deinit {
        workoutObservationTask?.cancel()
    }

    /// Re-loads the per-category exercise snapshot when the user switches
    /// workouts. The tile grid itself uses `MuscleCategoryGroup.allCases` and
    /// is workout-agnostic, but `exercisesByCategory` (used by the legacy
    /// Form/Picker path and by `findCategoryForExercise`) must be reseeded
    /// from the new workout's persisted exercises.
    private func startWorkoutObservation() {
        workoutObservationTask?.cancel()
        let ws = workoutStorageService
        workoutObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                let box = CheckedContinuationBox()
                let wasCancelled = await withTaskCancellationHandler {
                    await withCheckedContinuation { continuation in
                        box.store(continuation)
                        withObservationTracking {
                            _ = ws.currentWorkout
                        } onChange: {
                            box.resume(returning: false)
                        }
                    }
                } onCancel: {
                    box.resume(returning: true)
                }
                if wasCancelled || Task.isCancelled { return }
                guard let self else { return }
                self.refreshExercises()
            }
        }
    }

    public func resetAllExercises() {
        guard workoutStorageService.currentWorkout != nil else { return }
        resetAllExercisesUseCase.execute(for: MuscleCategoryGroup.allCases)
        refreshExercises()
    }

    public func refreshExercises() {
        var updated: [MuscleCategoryGroup: [Exercise]] = [:]
        for category in categories {
            updated[category] = exerciseManagementService.getExercises(for: category)
        }
        exercisesByCategory = updated
    }

    public func getExerciseCount(for group: MuscleCategoryGroup) -> (total: Int, active: Int)? {
        exerciseCounts[group]
    }

    public func hasActiveSetForCategory(_ group: MuscleCategoryGroup) -> Bool {
        coordinatorCache.coordinator(for: group).hasActiveSessions
    }

    /// Exposes the persisted ID of the currently selected workout so that
    /// SwiftData-backed views (e.g. `CategoryTileModelView` from
    /// `FitnessPersistenceUI`) can build a `@Query` predicate filtered by
    /// `workoutId`. Returns `nil` while no workout is selected; callers must
    /// guard the tile rendering on this value (the tile-grid otherwise still
    /// iterates `categories` = `allCases` even without a workout, but no
    /// query can resolve without a `workoutId`).
    public var currentWorkoutId: UUID? {
        workoutStorageService.currentWorkout?.id
    }

    public func getExercises(for category: MuscleCategoryGroup) -> [Exercise] {
        exercisesByCategory[category] ?? []
    }

    public func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.updateExercise(updatedExercise, category: category)
        refreshExercises()
    }

    public func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.addExercise(exercise, category: category, atTop: true)
        refreshExercises()
    }

    public func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup) {
        exerciseManagementService.resetExercise(exercise, category: category)
        refreshExercises()
    }

    public func findCategoryForExercise(_ exercise: Exercise) -> MuscleCategoryGroup? {
        for category in MuscleCategoryGroup.allCases {
            let exercises = getExercises(for: category)
            if exercises.contains(where: { $0.id == exercise.id }) {
                return category
            }
        }
        return nil
    }

    public func selectWorkout(_ workout: Workout) {
        workoutStorageService.setCurrentWorkout(workout)
    }
}
