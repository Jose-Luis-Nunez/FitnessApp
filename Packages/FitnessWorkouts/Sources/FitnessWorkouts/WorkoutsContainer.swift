import Factory

public extension Container {
    /// Singleton coordinator that bridges the App-level `.onOpenURL(_:)`
    /// handler with the WorkoutsScreen's import-sheet. Must be a singleton
    /// so cold-launch URL deliveries (which fire before the screen mounts)
    /// land in the same instance the screen later observes.
    var workoutImportCoordinator: Factory<WorkoutImportCoordinator> {
        self { MainActor.assumeIsolated { WorkoutImportCoordinator() } }.singleton
    }
}
