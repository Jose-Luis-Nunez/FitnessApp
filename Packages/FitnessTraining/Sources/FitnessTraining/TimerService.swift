import Foundation
import Observation

@Observable
@MainActor
public final class TimerService {
    public var timerSeconds: Int = 0
    private var timerTask: Task<Void, Never>?
    private var startTime: Date?
    private var isRunning: Bool = false

    public init() {}

    public func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()

        timerTask?.cancel()
        let start = startTime!
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.timerSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }

    public func resetAndStartTimer() {
        stopTimer()
        timerSeconds = 0
        startTimer()
    }

    public func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
        startTime = nil
    }
}
