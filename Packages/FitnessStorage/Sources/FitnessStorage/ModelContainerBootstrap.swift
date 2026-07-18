import Foundation
import os
import SwiftData

private let bootstrapLogger = Logger(subsystem: "FitnessStorage", category: "Bootstrap")

/// Builds the production `ModelContainer` for the persistent app store.
///
/// History: pre-T3 builds shipped a flat `ModelContainer(for: WorkoutModel.self, …)`
/// without any `VersionedSchema`. SwiftData stamped those stores with an implicit
/// schema identity that does not match `SchemaV1.versionIdentifier = (1,0,0)` once
/// `AppMigrationPlan` was introduced. Opening such a store with the plan throws
/// `SwiftDataError.loadIssueModelContainer` because there is no `(legacy → V1)`
/// stage. The fresh-install case never hits this — only devices that already had
/// the app installed before T3 do, which is why the simulator works and a real
/// phone with prior data crashes.
///
/// Strategy (in order, most preserving first):
///
/// 0. **Restore a prior quarantine.** Before touching the live store we check for
///    leftover `FitnessApp-store.bak-<ts>/` directories from a previous launch's
///    step 3. If one carries more data than the current live store *and* opens
///    cleanly now, we swap it back into place (see
///    `restoreQuarantinedStoreIfPossible`). This makes quarantine non-terminal:
///    a build where the open succeeds auto-recovers data an earlier build hid.
///
/// 1. **Open with the plan.** The current live schema is `SchemaV5`; opening with
///    `AppMigrationPlan` runs any pending forward migration (V1→V2→V3→V4→V5). This is
///    the only path for normal forward migrations once a store has a valid
///    versioned identity, and the only path that runs at all on a fresh install.
///
/// 2. **Adopt-as-V1, then re-open with the plan.** If (1) throws and we're on a
///    device that has an existing on-disk store, we open that store once with only
///    the `SchemaV1` snapshot classes and **no** migration plan. The V1 snapshots
///    intentionally mirror the pre-T3 storage shape (same property names/types),
///    so SwiftData accepts the existing rows and stamps the store with
///    `(1,0,0)`. We close that container immediately and re-open with the plan,
///    which now finds a valid starting point and runs the full V1→V2→V3→V4→V5 chain.
///
/// 3. **Quarantine + fresh start.** If (2) also fails (truly corrupt store, or a
///    shape we cannot map), we move the store files to a sibling `*.bak-<ts>/`
///    directory and open a fresh V5 container. We never silently delete user
///    data — the backup stays on disk for forensics, manual recovery, or the
///    automatic step-0 restore on a later launch.
///
/// The function only `fatalError`s when the OS itself denies us a writable
/// container directory, which is a non-recoverable environment problem.
///
/// **Migration coupling:** `makeProductionContainer()` runs
/// `DataMigrationService.migrateIfNeeded` on the freshly-opened container's
/// main context **before** returning. This is intentional: any caller resolving
/// `\.modelContainer` is guaranteed that legacy JSON/UserDefaults rows have
/// already been imported. Without this guarantee, a service like
/// `WorkoutStorageService` that initialises eagerly (e.g. as a SwiftUI `@State`
/// default) would observe an empty store, create a default "Workout 1", and
/// only **then** see the import land — leaving the user's real workouts orphaned
/// behind a freshly-created auto-default. The `WorkoutStorageService`
/// `healInheritedAutoDefaultIfNeeded` pass is the second line of defence that
/// repairs installs that already booted in this broken order.
public enum ModelContainerBootstrap {

    /// Directory-name prefix `quarantineAndRebuild` uses when it moves an
    /// unopenable store aside. `restoreQuarantinedStoreIfPossible` scans for
    /// siblings with this prefix on the next launch.
    static let quarantineDirPrefix = "FitnessApp-store.bak-"

    /// Directory-name prefix for the *previous* live store after a successful
    /// restore. Kept on disk (never deleted) for forensics / manual rollback.
    static let supersededDirPrefix = "FitnessApp-store.superseded-"

    public static func makeProductionContainer() -> ModelContainer {
        let storeURL = defaultStoreURL()
        restoreQuarantinedStoreIfPossible(liveStoreURL: storeURL)
        let container = makeContainer(storeURL: storeURL)
        runLegacyJSONMigration(on: container)
        return container
    }

    static func makeContainer(storeURL: URL) -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        let liveSchema = Schema(versionedSchema: SchemaV5.self)

        if let container = openWithMigrationPlan(schema: liveSchema, configuration: configuration) {
            return container
        }

        if FileManager.default.fileExists(atPath: storeURL.path),
           adoptStoreAsV1(at: storeURL),
           let container = openWithMigrationPlan(schema: liveSchema, configuration: configuration) {
            bootstrapLogger.notice("Recovered pre-T3 store by adopting it as SchemaV1; migration ran normally.")
            return container
        }

        return quarantineAndRebuild(storeURL: storeURL, schema: liveSchema, configuration: configuration)
    }

    /// Auto-recovers data that a previous launch quarantined (strategy step 0).
    ///
    /// When `makeContainer` cannot open the on-disk store with the migration
    /// plan, `quarantineAndRebuild` moves the store files into a sibling
    /// `FitnessApp-store.bak-<ts>/` and rebuilds a fresh, empty store. The user's
    /// data is preserved on disk but invisible in the app. On a later launch —
    /// typically a build where the open now succeeds — this method finds the
    /// richest recoverable backup and swaps it back into the live store path,
    /// **only** if that backup carries strictly more data than the current live
    /// store. That guard means a store already holding the user's real data is
    /// never clobbered, and a backup we still cannot open is left untouched.
    ///
    /// "Data richness" = workout count + total exercise count, measured by
    /// `storeDataScore` (opens the candidate with the plan + live schema). A
    /// store that cannot be opened scores as unrecoverable (`nil`) and is
    /// skipped — never deleted.
    static func restoreQuarantinedStoreIfPossible(liveStoreURL: URL) {
        let fm = FileManager.default
        let parent = liveStoreURL.deletingLastPathComponent()
        let storeName = liveStoreURL.lastPathComponent

        let backupDirs = ((try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(quarantineDirPrefix) }
            .filter { fm.fileExists(atPath: $0.appendingPathComponent(storeName).path) }
        guard !backupDirs.isEmpty else { return }

        let liveScore = fm.fileExists(atPath: liveStoreURL.path)
            ? (storeDataScore(at: liveStoreURL) ?? Int.min)
            : Int.min

        // Newest first so that, among equally rich backups, the most recent wins.
        let candidates = backupDirs.sorted { $0.lastPathComponent > $1.lastPathComponent }
        var best: (dir: URL, score: Int)?
        for dir in candidates {
            guard let score = storeDataScore(at: dir.appendingPathComponent(storeName)) else { continue }
            if best == nil || score > best!.score {
                best = (dir, score)
            }
        }

        guard let winner = best, winner.score > liveScore else { return }

        let backupStoreURL = winner.dir.appendingPathComponent(storeName)
        var supersededDir: URL?
        do {
            // 1. Preserve the live store by moving its whole family aside; the
            //    live path is now empty. A UUID suffix makes the name collision-
            //    proof if two restores land in the same wall-clock second.
            if fm.fileExists(atPath: liveStoreURL.path) {
                let dir = parent.appendingPathComponent(
                    "\(supersededDirPrefix)\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8))",
                    isDirectory: true
                )
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                for sibling in storeFamily(of: liveStoreURL) where fm.fileExists(atPath: sibling.path) {
                    try fm.moveItem(at: sibling, to: dir.appendingPathComponent(sibling.lastPathComponent))
                }
                supersededDir = dir
            }

            // 2. COPY (not move) the winning backup family into the live path.
            //    Copying keeps the backup intact until promotion is known to
            //    have fully succeeded, so a failure mid-loop can lose nothing.
            for sibling in storeFamily(of: backupStoreURL) where fm.fileExists(atPath: sibling.path) {
                try fm.copyItem(at: sibling, to: parent.appendingPathComponent(sibling.lastPathComponent))
            }

            // 3. Promotion succeeded — retire the consumed backup directory.
            try? fm.removeItem(at: winner.dir)
            bootstrapLogger.notice("Restored quarantined store from \(winner.dir.lastPathComponent, privacy: .public) (score \(winner.score, privacy: .public) > live \(liveScore, privacy: .public)).")
        } catch {
            // A move/copy failed partway. Roll the live path back to a whole
            // state: discard any partial copies, restore the original live
            // family from the superseded dir. The backup is untouched (we only
            // copied it), so nothing is lost.
            rollBackFailedRestore(liveStoreURL: liveStoreURL, supersededDir: supersededDir)
            bootstrapLogger.error("Quarantine restore failed; live store rolled back whole, backup left intact: \(String(describing: error), privacy: .public)")
        }
    }

    /// Undoes a partially-applied restore: removes any backup copies that
    /// landed in the live path, then moves the original live family back from
    /// `supersededDir`. Safe to call when no live store existed (`supersededDir
    /// == nil`) — it simply clears partial copies so the next launch sees a
    /// clean slate and re-evaluates.
    private static func rollBackFailedRestore(liveStoreURL: URL, supersededDir: URL?) {
        let fm = FileManager.default
        let parent = liveStoreURL.deletingLastPathComponent()
        for sibling in storeFamily(of: liveStoreURL) where fm.fileExists(atPath: sibling.path) {
            try? fm.removeItem(at: sibling)
        }
        guard let supersededDir else { return }
        for member in storeFamily(of: liveStoreURL) {
            let src = supersededDir.appendingPathComponent(member.lastPathComponent)
            if fm.fileExists(atPath: src.path) {
                try? fm.moveItem(at: src, to: parent.appendingPathComponent(member.lastPathComponent))
            }
        }
        try? fm.removeItem(at: supersededDir)
    }

    /// Opens the store at `url` with the live schema + plan and returns
    /// `workoutCount + totalExerciseCount`, or `nil` if the store cannot be
    /// opened (treated as unrecoverable). Opening migrates the store forward in
    /// place; for a backup that is harmless — it is a copy we are about to
    /// promote or discard. The container is scoped to this call so its file
    /// handles are released before the caller moves the underlying files.
    private static func storeDataScore(at url: URL) -> Int? {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let configuration = ModelConfiguration(url: url)
        do {
            let container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: configuration)
            let context = ModelContext(container)
            let workouts = try context.fetchCount(FetchDescriptor<WorkoutModel>())
            let exercises = try context.fetchCount(FetchDescriptor<ExerciseModel>())
            return workouts + exercises
        } catch {
            bootstrapLogger.error("Score open failed for \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Runs the JSON/UserDefaults → SwiftData migration on the freshly-opened
    /// container. Wrapped in `MainActor.assumeIsolated` because
    /// `DataMigrationService` is `@MainActor`-isolated and `Container` resolves
    /// `\.modelContainer` synchronously from the App's `init`, which itself
    /// runs on the main thread. This will trap if ever called off-main, which
    /// is correct — running the import off-main would race with the eager
    /// `WorkoutStorageService` `@State` resolution that this whole arrangement
    /// is designed to serialise.
    private static func runLegacyJSONMigration(on container: ModelContainer) {
        MainActor.assumeIsolated {
            DataMigrationService.migrateIfNeeded(context: container.mainContext)
        }
    }

    private static func openWithMigrationPlan(schema: Schema, configuration: ModelConfiguration) -> ModelContainer? {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            bootstrapLogger.error("Primary open with migration plan failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Opens the existing on-disk store with only the `SchemaV1` snapshot
    /// classes. The act of a successful open stamps the store with
    /// `SchemaV1.versionIdentifier`, which is what `AppMigrationPlan` needs to
    /// find a starting node on the next open.
    private static func adoptStoreAsV1(at url: URL) -> Bool {
        let v1Schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(url: url)
        do {
            _ = try ModelContainer(for: v1Schema, configurations: configuration)
            bootstrapLogger.notice("Adopted pre-T3 store as SchemaV1 at \(url.path, privacy: .public).")
            return true
        } catch {
            bootstrapLogger.error("Could not adopt store as SchemaV1: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private static func quarantineAndRebuild(
        storeURL: URL,
        schema: Schema,
        configuration: ModelConfiguration
    ) -> ModelContainer {
        let fm = FileManager.default
        if fm.fileExists(atPath: storeURL.path) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let backupDir = storeURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(quarantineDirPrefix)\(timestamp)", isDirectory: true)
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
                for sibling in storeFamily(of: storeURL) where fm.fileExists(atPath: sibling.path) {
                    let dest = backupDir.appendingPathComponent(sibling.lastPathComponent)
                    try fm.moveItem(at: sibling, to: dest)
                }
                bootstrapLogger.warning("Quarantined unrecoverable store to \(backupDir.path, privacy: .public).")
            } catch {
                bootstrapLogger.error("Failed to quarantine store, attempting fresh open anyway: \(String(describing: error), privacy: .public)")
            }
        }

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not create a fresh ModelContainer after quarantine: \(error)")
        }
    }

    /// SwiftData/SQLite writes a `*.store`, `*.store-shm`, `*.store-wal` triplet.
    /// All three move together when we quarantine or restore.
    private static func storeFamily(of url: URL) -> [URL] {
        let base = url.path
        return [
            url,
            URL(fileURLWithPath: base + "-shm"),
            URL(fileURLWithPath: base + "-wal")
        ]
    }

    private static func defaultStoreURL() -> URL {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            fatalError("Application Support directory unavailable — environment is non-recoverable.")
        }
        return appSupport.appendingPathComponent("default.store")
    }
}
