import Foundation
import os
import SwiftData

private let migrationLogger = Logger(subsystem: "FitnessStorage", category: "AppMigrationPlan")

/// Plan controlling forward migrations between SchemaV1 → SchemaV2 → SchemaV3 → ...
///
/// Per ADR-0005, every Custom Stage MUST have a dedicated test exercising
/// the real container-version transition (see `MigrationV1toV2Tests`,
/// `MigrationV2toV3Tests`).
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2_addWorkoutId, migrateV2toV3_addFriendModel, migrateV3toV4_addIsActive, migrateV4toV5_addWorkoutType]
    }

    /// V4 → V5: adds `WorkoutModel.typeRaw: String?`. Existing rows remain
    /// `nil` and are interpreted as `.individual`; new writes store a raw value.
    static let migrateV4toV5_addWorkoutType = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    /// V3 → V4: adds `ExerciseModel.isActive: Bool?`. Lightweight because it is a
    /// single additive, optional scalar — SwiftData adds the column as `NULL` for
    /// existing rows. No backfill/`didMigrate` needed: read paths interpret an
    /// absent value as active (`isActive ?? true`). Being lightweight, it needs no
    /// dedicated migration test (only Custom Stages do, per ADR-0005).
    static let migrateV3toV4_addIsActive = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )

    /// V1 → V2: SwiftData's lightweight phase adds the new column `workoutId: UUID?`
    /// initialised to `NULL` for all existing rows. Then `didMigrate` runs on the
    /// V2 store and backfills `workoutId` from the still-attached `workout?.id`
    /// relationship that was carried over from V1.
    ///
    /// `workoutId` is Optional because non-optional new properties cannot pass
    /// SwiftData's lightweight validation step — see ADR-0005 § "Optionality
    /// rule for new properties".
    ///
    /// Failure handling: rows whose `workout` relationship is `nil` (orphans from
    /// older corruption) stay with `workoutId == nil`; we log them and continue
    /// rather than `fatalError`-ing — a failed migration would brick the install.
    /// The next save through `ExerciseModel.from(_:sortOrder:workout:)` will
    /// assign a real value.
    /// V2 → V3: adds `FriendModel`. Lightweight because we only add a new model
    /// with scalar fields and no relationships. No `willMigrate`/`didMigrate`
    /// needed — existing rows are unaffected; the new table starts empty.
    static let migrateV2toV3_addFriendModel = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    static let migrateV1toV2_addWorkoutId = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // Destination of this stage is SchemaV2 — fetch the V2 snapshot type,
            // not the live `ExerciseModel` (whose current shape includes
            // `isActive` and would not match the V2 store shape).
            let descriptor = FetchDescriptor<SchemaV2.ExerciseModel>()
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
