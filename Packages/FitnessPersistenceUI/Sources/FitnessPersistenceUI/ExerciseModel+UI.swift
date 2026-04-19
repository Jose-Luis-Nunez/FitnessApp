import SwiftUI
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Convenience-Reads die heute auf `Exercise` (struct) als computed properties leben.
/// In `FitnessPersistenceUI` brauchen die `*ModelView`-Cards die gleiche Surface,
/// aber direkt auf dem `@Model` — ohne über `model.toDomain()` einen Snapshot pro
/// body-recompute anzulegen (das wäre genau das Anti-Pattern aus ADR-0001).
///
/// Diese Extensions sind absichtlich **dünn**: Sie spiegeln genau die computed
/// properties die heute in `Exercise.swift` und `MuscleCategoryGroup+UI.swift`
/// definiert sind. Falls die Source-of-Truth-Properties dort wachsen, wachsen
/// sie hier mit. T8 löscht die struct-seitigen Equivalents wenn die letzte
/// `Exercise`-konsumierende View weg ist.
@_spi(PersistenceUI)
extension ExerciseModel {

    /// Spiegelt `Exercise.hasWeight`.
    public var hasWeight: Bool { weight > 0 }

    /// Spiegelt `Exercise.displayIconName`: nimmt den eigenen `iconName` wenn er
    /// in der Category-Icon-Liste ist, sonst den Category-Default.
    public var displayIconName: String {
        categoryGroup.availableIcons.contains(iconName)
            ? iconName
            : categoryGroup.defaultIconName
    }

    /// Map zur `MuscleCategoryGroup`-Enum für Icon-Alignment / Default-Icon-Lookup.
    public var categoryGroup: MuscleCategoryGroup {
        MuscleCategoryGroup(rawValue: category) ?? .arms
    }

    /// Spiegelt `Exercise.iconAlignment` aus `MuscleCategoryGroup+UI.swift`.
    public var iconAlignment: Alignment {
        categoryGroup.iconAlignment
    }
}
