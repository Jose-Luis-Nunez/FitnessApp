import Foundation
import os
import SwiftData

private let migrationLogger = Logger(subsystem: "FitnessStorage", category: "AppMigrationPlan")

/// Plan controlling forward migrations between SchemaV1 → SchemaV2 → ...
///
/// Per ADR-0005, every Custom Stage MUST have a dedicated test exercising
/// the real container-version transition (see `MigrationV1toV2Tests`).
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2_addWorkoutId]
    }

    /// V1 → V2: SwiftData's lightweight phase adds the new column `workoutId: UUID?`
    /// initialised to `NULL` for all existing rows. Then `didMigrate` runs on the
    /// V2 store and backfills `workoutId` from the still-attached `workout?.id`
    /// relationship that was carried over from V1.
    ///
    /// `workoutId` is Optional because non-optional new properties cannot pass
    /// SwiftData's lightweight validation step — see ADR-0005 § "Optionalitäts-
    /// Regel für neue Properties".
    ///
    /// Failure handling: rows whose `workout` relationship is `nil` (orphans from
    /// older corruption) stay with `workoutId == nil`; we log them and continue
    /// rather than `fatalError`-ing — a failed migration would brick the install.
    /// The next save through `ExerciseModel.from(_:sortOrder:workout:)` will
    /// assign a real value.
    static let migrateV1toV2_addWorkoutId = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let descriptor = FetchDescriptor<ExerciseModel>()
            let all = try context.fetch(descriptor)
            var fixed = 0
            var orphaned = 0
            for model in all {
                if let realId = model.workout?.id {
                    if model.workoutId != realId {
                        model.workoutId = realId
                        fixed += 1
                    }
                } else {
                    orphaned += 1
                }
            }
            if fixed > 0 || orphaned > 0 {
                migrationLogger.info("V1->V2: backfilled workoutId for \(fixed, privacy: .public) rows; \(orphaned, privacy: .public) orphans kept with workoutId=nil")
                try context.save()
            }
        }
    )
}
