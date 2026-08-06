import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessAnalytics
import Factory

// MARK: - Protocol

@MainActor
public protocol TrainingCoordinatorCaching: AnyObject {
    func coordinator(for group: MuscleCategoryGroup) -> TrainingCoordinator
    func findCoordinator(for exercise: Exercise) -> (TrainingCoordinator, MuscleCategoryGroup)?
}

// MARK: - Implementation

@Observable
@MainActor
public final class TrainingCoordinatorCache: TrainingCoordinatorCaching {
    private var coordinators: [MuscleCategoryGroup: TrainingCoordinator] = [:]

    @ObservationIgnored private var exerciseManagementService: ExerciseManaging
    @ObservationIgnored private var exerciseOrderStorage: WorkoutExerciseOrderStoring
    @ObservationIgnored private let analyticsViewModel: AnalyticsViewModel

    public init(
        exerciseManagement: ExerciseManaging? = nil,
        exerciseOrderStorage: WorkoutExerciseOrderStoring? = nil,
        analyticsViewModel: AnalyticsViewModel? = nil
    ) {
        self.exerciseManagementService = exerciseManagement ?? Container.shared.exerciseManagement()
        self.exerciseOrderStorage = exerciseOrderStorage
            ?? Container.shared.workoutExerciseOrderStorage()
        self.analyticsViewModel = analyticsViewModel
            ?? Container.shared.analyticsViewModel()
    }

    public func coordinator(for group: MuscleCategoryGroup) -> TrainingCoordinator {
        if let existing = coordinators[group] {
            return existing
        }
        let coordinator = TrainingCoordinator(
            findCategory: { _ in group },
            onExerciseUpdate: { [weak self] exercise, category in
                self?.exerciseManagementService.updateExercise(exercise, category: category)
            },
            onExerciseReset: { [weak self] exercise, category in
                self?.exerciseManagementService.resetExercise(exercise, category: category)
            },
            onNewSessionStarted: { [weak self] workoutId, exerciseId in
                self?.exerciseOrderStorage.recordStart(
                    workoutId: workoutId,
                    exerciseId: exerciseId
                )
            },
            analyticsViewModel: analyticsViewModel
        )
        coordinators[group] = coordinator
        return coordinator
    }

    public func findCoordinator(for exercise: Exercise) -> (TrainingCoordinator, MuscleCategoryGroup)? {
        for (group, coordinator) in coordinators {
            if coordinator.isExerciseInProgress(exercise.id) {
                return (coordinator, group)
            }
        }
        return nil
    }
}
