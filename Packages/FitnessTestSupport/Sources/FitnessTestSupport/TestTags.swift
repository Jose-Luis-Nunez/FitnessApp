import Testing

extension Tag {
    /// Pure logic tests — no simulator, no disk, no network.
    @Tag public static var fast: Self

    /// Snapshot image comparison tests (swift-snapshot-testing).
    @Tag public static var snapshot: Self

    /// Tests that use SwiftData in-memory containers or UserDefaults.
    @Tag public static var integration: Self

    /// XCUITest end-to-end flows.
    @Tag public static var ui: Self
}
