import SwiftUI
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Convenience reads that today live on `Exercise` (struct) as computed properties.
/// In `FitnessPersistenceUI` the `*ModelView` cards need the same surface,
/// but directly on the `@Model` — without creating a snapshot per body recompute
/// via `model.toDomain()` (that would be exactly the anti-pattern from ADR-0001).
///
/// These extensions are intentionally **thin**: they mirror exactly the computed
/// properties that are defined today in `Exercise.swift` and
/// `MuscleCategoryGroup+UI.swift`. If the source-of-truth properties there grow,
/// they grow here too. T8 deletes the struct-side equivalents once the last
/// `Exercise`-consuming view is gone.
@_spi(PersistenceUI)
extension ExerciseModel {

    /// Mirrors `Exercise.hasWeight`.
    public var hasWeight: Bool { weight > 0 }

    /// Mirrors `Exercise.displayIconName`: takes the own `iconName` if it is
    /// in the category icon list, otherwise the category default.
    public var displayIconName: String {
        categoryGroup.availableIcons.contains(iconName)
            ? iconName
            : categoryGroup.defaultIconName
    }

    /// Maps to the `MuscleCategoryGroup` enum for icon alignment / default-icon lookup.
    public var categoryGroup: MuscleCategoryGroup {
        MuscleCategoryGroup(rawValue: category) ?? .arms
    }

    /// Mirrors `Exercise.iconAlignment` from `MuscleCategoryGroup+UI.swift`.
    public var iconAlignment: Alignment {
        categoryGroup.iconAlignment
    }

    /// Mirrors `Exercise.allowsSeatEditing`: whether the seat-edit affordance
    /// (tapping the body icon) should be offered. Unlike name/weight edits —
    /// which the cards gate behind `isEditable` — the seat is a physical setup
    /// the user adjusts *during* the exercise, so it stays editable even while a
    /// set is in progress. Only `noSeats` exercises suppress it.
    public var allowsSeatEditing: Bool { !noSeats }
}
