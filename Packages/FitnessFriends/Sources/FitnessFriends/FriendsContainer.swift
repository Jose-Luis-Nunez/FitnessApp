import Factory

public extension Container {
    /// Singleton coordinator that bridges the App-level `.onOpenURL(_:)`
    /// handler (for `.fitnessfriend` files) with `FriendsSection`. Must be a
    /// singleton so cold-launch URL deliveries land in the same instance the
    /// view later observes.
    var friendImportCoordinator: Factory<FriendImportCoordinator> {
        self { MainActor.assumeIsolated { FriendImportCoordinator() } }.singleton
    }
}
