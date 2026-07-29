import Foundation
import SwiftData
import Testing
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

/// Tests for `ModelContainerBootstrap`, the production fallback chain that
/// turns the pre-T3 → T3 migration crash on real devices into a transparent
/// upgrade.
///
/// Why these tests exist: pre-T3 builds opened the store as
/// `ModelContainer(for: WorkoutModel.self, …)` with no `VersionedSchema`. Once
/// T3 introduced `AppMigrationPlan`, opening such a store with the plan throws
/// `SwiftDataError.loadIssueModelContainer` because there is no
/// `(legacy → V1)` stage. The bootstrap recovers by adopting the on-disk store
/// as `SchemaV1` first (which physically matches the pre-T3 shape and stamps
/// it with `(1,0,0)`), then re-opens with the plan so the existing
/// `migrateV1toV2_addWorkoutId` (and now `migrateV2toV3_addFriendModel`) run and
/// user data survives.
///
/// Unlike before, these tests call the **real** `ModelContainerBootstrap`
/// entry points (`makeContainer(storeURL:)`,
/// `restoreQuarantinedStoreIfPossible(liveStoreURL:)`) against per-test scratch
/// URLs, so there is no reimplemented copy of the strategy to drift out of sync
/// with production. We never call `makeProductionContainer()` directly because
/// it pins the store to `Application Support/default.store`, which would clobber
/// the dev simulator's app data.
@MainActor
@Suite("ModelContainerBootstrap recovers pre-versioned stores", .serialized, .tags(.integration))
struct ModelContainerBootstrapTests {

    private func makeStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "BootstrapRecovery-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "default.store")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// Reproduces a pre-T3 store: opens a SwiftData container with the live
    /// classes **without** declaring `Schema(versionedSchema:)`. SwiftData
    /// stamps the store with an implicit identity that is not `(1,0,0)`. This
    /// is the exact shape on the user's phone in the original bug report.
    private func writeLegacyPreVersionedStore(at url: URL, workoutId: UUID, exerciseId: UUID) throws {
        let legacy = try ModelContainer(
            for: SchemaV1.WorkoutModel.self,
            SchemaV1.ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(legacy)
        let workout = SchemaV1.WorkoutModel(
            id: workoutId, name: "Pre-T3", selectedCategories: ["arms"],
            createdDate: .now, lastModified: .now
        )
        let exercise = SchemaV1.ExerciseModel(
            id: exerciseId, name: "Curl", weight: 20, reps: 10, sets: 3,
            iconName: "x", category: "arms"
        )
        exercise.workout = workout
        ctx.insert(workout)
        ctx.insert(exercise)
        try ctx.save()
    }

    @Test("Fresh install: container opens directly, no recovery needed")
    func freshInstallTakesPrimaryPath() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let container = ModelContainerBootstrap.makeContainer(storeURL: url)
        let ctx = ModelContext(container)
        let count = try ctx.fetchCount(FetchDescriptor<ExerciseModel>())
        #expect(count == 0)
    }

    @Test("Pre-T3 store: V1 adoption unblocks the plan and preserves data through V1→V2→V3")
    func preT3StoreRecoversAndMigrates() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let workoutId = UUID()
        let exerciseId = UUID()
        try writeLegacyPreVersionedStore(at: url, workoutId: workoutId, exerciseId: exerciseId)

        let container = ModelContainerBootstrap.makeContainer(storeURL: url)
        let ctx = ModelContext(container)
        let fetched = try #require(try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == exerciseId }
        )).first)

        #expect(fetched.workoutId == workoutId, "Migration must backfill workoutId from carried-over relationship")
        #expect(fetched.workout?.id == workoutId, "Relationship must survive the legacy → V1 → V2 → V3 pipeline")
        // FriendModel table must exist and be queryable after the chained migration.
        #expect(try ctx.fetchCount(FetchDescriptor<FriendModel>()) == 0)
    }

    @Test("Recovered store re-opens directly on subsequent launches")
    func recoveredStoreOpensDirectlyNextTime() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        try writeLegacyPreVersionedStore(at: url, workoutId: UUID(), exerciseId: UUID())
        _ = ModelContainerBootstrap.makeContainer(storeURL: url)

        let secondOpen = try ModelContainer(
            for: Schema(versionedSchema: SchemaV6.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(secondOpen)
        #expect(try ctx.fetchCount(FetchDescriptor<ExerciseModel>()) == 1)
    }
}

/// Tests for the boot-time quarantine restore (strategy step 0). A previous
/// launch may have moved an unopenable store into a sibling
/// `FitnessApp-store.bak-<ts>/`; on a later launch where the open succeeds we
/// promote the richest recoverable backup back into the live path — but only
/// when it carries strictly more data than the current live store.
@MainActor
@Suite("ModelContainerBootstrap restores quarantined backups", .serialized, .tags(.integration))
struct ModelContainerBootstrapRestoreTests {

    private func makeDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "BootstrapRestore-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    /// Populates a store at `url` (opening with the live schema + plan) with
    /// `workouts` workouts, each holding `exercisesEach` exercises. The
    /// resulting `storeDataScore` is `workouts + workouts * exercisesEach`.
    private func writeStore(at url: URL, workouts: Int, exercisesEach: Int) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV6.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(container)
        for w in 0..<workouts {
            let wm = WorkoutModel(
                id: UUID(), name: "W\(w)", selectedCategories: ["legs"],
                createdDate: .now, lastModified: .now
            )
            ctx.insert(wm)
            for e in 0..<exercisesEach {
                ctx.insert(ExerciseModel.from(
                    Exercise(name: "E\(w)-\(e)", weight: 1, reps: 1, sets: 1, iconName: "x", category: .legs),
                    sortOrder: e,
                    workout: wm
                ))
            }
        }
        try ctx.save()
    }

    private func score(at url: URL) throws -> Int {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV6.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(container)
        return try ctx.fetchCount(FetchDescriptor<WorkoutModel>())
            + ctx.fetchCount(FetchDescriptor<ExerciseModel>())
    }

    @Test("Richer backup is restored over a freshly-seeded (sparse) live store")
    func restoresRicherBackup() throws {
        let dir = makeDir()
        defer { cleanup(dir) }

        let liveURL = dir.appending(path: "default.store")
        try writeStore(at: liveURL, workouts: 1, exercisesEach: 0) // seed-like, score 1

        let backupDir = dir.appending(path: "\(ModelContainerBootstrap.quarantineDirPrefix)100")
        try writeStore(at: backupDir.appending(path: "default.store"), workouts: 2, exercisesEach: 3) // score 8

        ModelContainerBootstrap.restoreQuarantinedStoreIfPossible(liveStoreURL: liveURL)

        #expect(try score(at: liveURL) == 8, "live store must now carry the backup's data")
        #expect(!FileManager.default.fileExists(atPath: backupDir.path), "consumed backup dir is removed")
    }

    @Test("Live store with more data is NOT clobbered by a sparser backup")
    func keepsRicherLiveStore() throws {
        let dir = makeDir()
        defer { cleanup(dir) }

        let liveURL = dir.appending(path: "default.store")
        try writeStore(at: liveURL, workouts: 3, exercisesEach: 2) // score 9

        let backupDir = dir.appending(path: "\(ModelContainerBootstrap.quarantineDirPrefix)100")
        try writeStore(at: backupDir.appending(path: "default.store"), workouts: 1, exercisesEach: 0) // score 1

        ModelContainerBootstrap.restoreQuarantinedStoreIfPossible(liveStoreURL: liveURL)

        #expect(try score(at: liveURL) == 9, "richer live store is preserved")
        #expect(FileManager.default.fileExists(atPath: backupDir.path), "untaken backup is left on disk")
    }

    @Test("Unreadable backup is left untouched, never deleted")
    func skipsUnreadableBackup() throws {
        let dir = makeDir()
        defer { cleanup(dir) }

        let liveURL = dir.appending(path: "default.store")
        try writeStore(at: liveURL, workouts: 1, exercisesEach: 0)

        let backupDir = dir.appending(path: "\(ModelContainerBootstrap.quarantineDirPrefix)100")
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        try Data("not a sqlite store".utf8).write(to: backupDir.appending(path: "default.store"))

        ModelContainerBootstrap.restoreQuarantinedStoreIfPossible(liveStoreURL: liveURL)

        #expect(try score(at: liveURL) == 1, "live store unchanged when backup is unreadable")
        #expect(FileManager.default.fileExists(atPath: backupDir.path), "unreadable backup preserved for forensics")
    }
}
