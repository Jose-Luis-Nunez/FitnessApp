import Foundation

public struct WaitUntilTimeoutError: Error, CustomStringConvertible {
    public let timeout: Duration
    public let file: String
    public let line: Int

    public var description: String {
        "waitUntil timed out after \(timeout) (\(file):\(line))"
    }
}

@MainActor
public func waitUntil(
    timeout: Duration = .milliseconds(500),
    interval: Duration = .milliseconds(10),
    _ condition: @MainActor () -> Bool,
    file: String = #file,
    line: Int = #line
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: interval)
    }
    throw WaitUntilTimeoutError(timeout: timeout, file: file, line: line)
}
