import Foundation
import FitnessCore

/// Mirrors app navigation destinations for use when hosting exercise feature from SPM.
public enum NavigationDestination: Hashable {
    case home
    case profile
    case totalAnalytics
    case schedule
    case muscleCategory(MuscleCategoryGroup)
    /// Training screen for a specific exercise.
    ///
    /// Carries `exerciseId: UUID` rather than the full `Exercise` value (or the
    /// SwiftData `ExerciseModel`) for two reasons:
    /// 1. `ExerciseModel` is `@_spi(PersistenceUI) public` and importing it
    ///    here would leak the SPI boundary into a Domain-near enum.
    /// 2. The destination view (`TrainingView`) resolves the id to a live
    ///    `ExerciseModel` via `@Query`, so any subsequent edit (rename, weight
    ///    change, etc.) is picked up automatically — no stale snapshot.
    case training(exerciseId: UUID, category: MuscleCategoryGroup)
}
