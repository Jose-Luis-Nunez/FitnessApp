/// Pure, side-effect-free rules for which exercises are selectable in the
/// deactivate/activate multi-select mode. Extracted so both host views
/// (`MuscleCategoryView`, `MuscleCategorySelectionView`) share one definition
/// instead of duplicating the branching, and so the rule is unit-testable
/// without a view or a SwiftData store.
public enum ExerciseSelectionRules {

    /// - In `.deactivate`: only **idle** exercises (active, not completed, not
    ///   currently training) can be ticked.
    /// - In `.activate`: only **deactivated** exercises can be ticked.
    /// - In `.none`: nothing is selectable.
    ///
    /// The caller supplies `isInProgress` from whatever training-session source
    /// it owns (per-category coordinator vs. coordinator cache), keeping this
    /// rule independent of the session layer.
    public static func isSelectable(
        mode: ExerciseSelectionMode,
        isActive: Bool,
        isCompleted: Bool,
        isInProgress: Bool
    ) -> Bool {
        switch mode {
        case .deactivate:
            return isActive && !isCompleted && !isInProgress
        case .activate:
            return !isActive
        case .none:
            return false
        }
    }
}
