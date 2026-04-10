import Combine
import Foundation

public final class TimerService: ObservableObject {
    @Published public var timerSeconds: Int = 0
    private var timerSource: DispatchSourceTimer?
    private var startTime: Date?
    private var isRunning: Bool = false

    public init() {}

    public func startTimer() {
        guard !isRunning else { return }
        timerSource?.cancel()
        isRunning = true
        startTime = Date()

        let source = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        source.schedule(deadline: .now(), repeating: 1.0)
        source.setEventHandler { [weak self] in
            guard let self, let start = self.startTime else { return }
            let seconds = Int(Date().timeIntervalSince(start))
            DispatchQueue.main.async {
                self.timerSeconds = seconds
            }
        }
        timerSource = source
        source.resume()
    }

    public func resetAndStartTimer() {
        timerSeconds = 0
        startTimer()
    }

    public func stopTimer() {
        timerSource?.cancel()
        timerSource = nil
        isRunning = false
        startTime = nil
    }
}
