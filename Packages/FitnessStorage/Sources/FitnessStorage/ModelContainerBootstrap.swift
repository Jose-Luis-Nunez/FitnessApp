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
/// 1. **Open as V2 with the plan.** The dokumentierte Apple form. This is the
///    only path for normal forward migrations once a store has a valid
///    versioned identity, and the only path that runs at all on a fresh install.
///
/// 2. **Adopt-as-V1, then re-open as V2.** If (1) throws and we're on a device
///    that has an existing on-disk store, we open that store once with only the
///    `SchemaV1` snapshot classes and **no** migration plan. The V1 snapshots
///    intentionally mirror the pre-T3 storage shape (same property names/types),
///    so SwiftData accepts the existing rows and stamps the store with
///    `(1,0,0)`. We close that container immediately and re-open with the plan,
///    which now finds a valid starting point and runs
///    `migrateV1toV2_addWorkoutId` normally.
///
/// 3. **Quarantine + fresh start.** If (2) also fails (truly corrupt store, or a
///    shape we cannot map), we move the store files to a sibling `*.bak-<ts>/`
///    directory and open a fresh V2 container. We never silently delete user
///    data — the backup stays on disk for forensics or manual recovery.
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
    public static func makeProductionContainer() -> ModelContainer {
        let container = makeContainer()
        runLegacyJSONMigration(on: container)
        return container
    }

    private static func makeContainer() -> ModelContainer {
        let storeURL = defaultStoreURL()
        let configuration = ModelConfiguration(url: storeURL)
        let v2Schema = Schema(versionedSchema: SchemaV2.self)

        if let container = openV2(schema: v2Schema, configuration: configuration) {
            return container
        }

        if FileManager.default.fileExists(atPath: storeURL.path),
           adoptStoreAsV1(at: storeURL),
           let container = openV2(schema: v2Schema, configuration: configuration) {
            bootstrapLogger.notice("Recovered pre-T3 store by adopting it as SchemaV1; migration ran normally.")
            return container
        }

        return quarantineAndRebuild(storeURL: storeURL, schema: v2Schema, configuration: configuration)
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

    private static func openV2(schema: Schema, configuration: ModelConfiguration) -> ModelContainer? {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            bootstrapLogger.error("Primary V2 open failed: \(String(describing: error), privacy: .public)")
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
                .appendingPathComponent("FitnessApp-store.bak-\(timestamp)", isDirectory: true)
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
    /// All three move together when we quarantine.
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
