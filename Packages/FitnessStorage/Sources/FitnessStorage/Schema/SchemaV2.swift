import Foundation
import SwiftData

/// V2: ExerciseModel bekommt das denormalisierte FK-Feld `workoutId: UUID`
/// (`@Attribute(.indexed)`) um Optional-Chain-Predicates (§14a) zu vermeiden.
///
/// Per ADR-0005 § Snapshot-Pflicht (Hybrid-Regel): V2 ist die jüngste
/// Schema-Version und referenziert daher ausschließlich die Live-Klassen
/// in `Models/`. Keine Snapshots, weil V2 = aktueller Live-Stand.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutModel.self,
            ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self
        ]
    }
}
