import Foundation

/// Three rendering states a single exercise card can be in.
///
/// Lives in `FitnessCore` (no SwiftUI dependency) because it is a domain
/// concept — derived from the persisted `isCompleted` flag and the live
/// session state — not a UI pixel. Consumed by `ExerciseCardModelView`
/// (in `FitnessPersistenceUI`). Hoisted here as part of T7-0 to break the
/// `FitnessPersistenceUI → FitnessExercise` dependency cycle.
public enum CardVariant: Equatable, Sendable {
    case completed
    case active
    case idle
}

/// Deterministic, side-effect-free resolver for `CardVariant`. Pure
/// function: same inputs → same output, no global state, no `@MainActor`
/// requirement.
///
/// - Parameters:
///   - isCompleted: `true` if the exercise has been marked as fully done
///     for this session. Dominates all other inputs.
///   - isActiveSetVisible: `true` if the parent screen is currently showing
///     the active-set workspace (typically `TrainingView`). When `false`,
///     no card can be `.active` regardless of the focused exercise id.
///   - activeExerciseId: id of the currently focused exercise in the
///     coordinator session, or `nil` if no session is focused on a single
///     exercise.
///   - exerciseId: id of the exercise this card represents.
public func resolveCardVariant(
    isCompleted: Bool,
    isActiveSetVisible: Bool,
    activeExerciseId: UUID?,
    exerciseId: UUID
) -> CardVariant {
    if isCompleted { return .completed }
    if isActiveSetVisible, activeExerciseId == exerciseId { return .active }
    return .idle
}
