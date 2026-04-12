import Foundation
import Testing

@MainActor
public func waitUntil(
    timeout: Duration = .milliseconds(500),
    interval: Duration = .milliseconds(10),
    _ condition: @MainActor () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: interval)
    }
    Issue.record("waitUntil timed out after \(timeout)", sourceLocation: sourceLocation)
}
