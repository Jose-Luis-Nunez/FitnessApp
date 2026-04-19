// FitnessPersistenceUI
//
// Primary SwiftUI integration surface for SwiftData `@Model` types. Hosts
// `@Query`/`@Bindable`-driven views (ExerciseCardModelView,
// CategoryTileModelView, …) introduced in T5+.
//
// Per ADR-0002 this is the **primary** consumer of `@_spi(PersistenceUI)
// import FitnessStorage`, but not the only one: specific views in
// `FitnessExercise` (e.g. `MuscleCategorySelectionView`,
// `MuscleCategoryView`) also import the SPI to host `@Query`s that drive
// the ModelViews exported here (T7a/T7b/T8a). Every new such consumer is
// a deliberate boundary loosening and is review-required.
//
// Other feature packages remain DTO-oriented and consume `Exercise` /
// `Workout` value types from `FitnessCore`.

import SwiftData
import SwiftUI

public enum FitnessPersistenceUI {
    /// Marker symbol so the module compiles even before the first concrete
    /// view ships. Removed once a real public type lives here.
    public static let moduleVersion: String = "0.1.0"
}
