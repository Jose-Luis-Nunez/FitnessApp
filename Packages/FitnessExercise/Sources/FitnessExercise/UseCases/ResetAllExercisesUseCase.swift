import Foundation
import FitnessCore
import FitnessStorage
import FitnessTraining
import Factory

@MainActor
public struct ResetAllExercisesUseCase {
    @Injected(\.sessionTrainingCache) private var sessionTrainingCache
    @Injected(\.exerciseManagement) private var exerciseManagementService

    public init() {}

    /// Cancels all active sets and resets exercises across all categories.
    public func execute(for categories: [MuscleCategoryGroup]) {
        for (_, activeSetVM) in sessionTrainingCache.activeSetVMs {
            activeSetVM.cancelActiveSet()
        }

        exerciseManagementService.resetAllExercises(for: categories)
    }
}
