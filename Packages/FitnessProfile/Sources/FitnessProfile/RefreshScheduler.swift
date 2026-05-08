import Foundation

/// Composable helper that captures the auto-refresh + failure-backoff
/// behaviour shared by `TramDeparturesViewModel` and
/// `SBahnDeparturesViewModel`. Each ViewModel composes one and delegates
/// scheduling/backoff decisions to it; the actual `refresh()` body still
/// lives in the ViewModel because it's typed (different services).
///
/// Lifecycle:
/// - `schedule(_:)` cancels any in-flight task and starts a new one.
/// - On success → call `reportSuccess()` to clear the failure marker.
/// - On failure → call `reportFailure()` to set the marker.
/// - Before any auto-refresh (e.g. `onBecameActive`) consult
///   `shouldSkipAutoRefresh(staleThreshold:)` to honour the backoff.
///
/// Manual refreshes (RefreshActionButton, swap) bypass this scheduler's
/// `shouldSkipAutoRefresh` check by design — user intent always wins over
/// automatic suppression.
@MainActor
public final class RefreshScheduler {
    public private(set) var lastFailureAt: Date?
    private var activeTask: Task<Void, Never>?

    public init() {}

    /// Cancels any in-flight task and schedules a new one. The task body
    /// receives no arguments and must call `reportSuccess`/`reportFailure`
    /// from inside its own logic so the scheduler stays in sync.
    public func schedule(_ work: @escaping @MainActor () async -> Void) {
        activeTask?.cancel()
        activeTask = Task { @MainActor in
            await work()
        }
    }

    /// Mark the most recent attempt as a success. Clears the failure
    /// marker so future auto-refreshes are not suppressed.
    public func reportSuccess() {
        lastFailureAt = nil
    }

    /// Mark the most recent attempt as a failure. The timestamp is used
    /// by `shouldSkipAutoRefresh` to suppress redundant retries.
    public func reportFailure() {
        lastFailureAt = Date()
    }

    /// Returns `true` if the last failure happened within `staleThreshold`
    /// seconds — meaning an auto-refresh should be suppressed. Manual
    /// refresh callers should NOT consult this; their intent always wins.
    public func shouldSkipAutoRefresh(staleThreshold: TimeInterval, now: Date = Date()) -> Bool {
        guard let lastFailureAt else { return false }
        return now.timeIntervalSince(lastFailureAt) < staleThreshold
    }

    /// For tests: clear all internal state.
    func reset() {
        activeTask?.cancel()
        activeTask = nil
        lastFailureAt = nil
    }
}
