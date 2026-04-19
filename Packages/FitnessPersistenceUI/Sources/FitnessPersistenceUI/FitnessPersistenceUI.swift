// FitnessPersistenceUI
//
// Single SwiftUI integration surface for SwiftData `@Model` types.
// Hosts `@Query`/`@Bindable`-driven views (e.g. ExerciseCardModelView,
// CategoryTileModelView) introduced in T5+. Per ADR-0002, this is the
// only module that may carry `@_spi(PersistenceUI) import FitnessStorage`;
// other feature packages stay DTO-oriented and consume `Exercise`/`Workout`
// value types from FitnessCore.
//
// Skeleton-only in T4. Pilot views land in T5/T6/T7.

import SwiftData
import SwiftUI

public enum FitnessPersistenceUI {
    /// Marker symbol so the module compiles even before the first concrete
    /// view ships. Removed once a real public type lives here.
    public static let moduleVersion: String = "0.1.0"
}
