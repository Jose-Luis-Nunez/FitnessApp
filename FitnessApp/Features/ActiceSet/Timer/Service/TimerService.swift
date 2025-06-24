import Combine
import Foundation

class TimerService {
    @Published var timerSeconds: Int = 0
    private var timer: Timer?
    private var startTime: Date?
    private var isRunning: Bool = false
    
    func startTimer() {
        guard !isRunning else { return }
        timer?.invalidate()
        isRunning = true
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.timerSeconds = Int(Date().timeIntervalSince(start))
        }
        timer?.fire()
    }
    
    func resetAndStartTimer() {
        timerSeconds = 0
        startTimer()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        startTime = nil
    }
    
    func updateTimer() {
        if isRunning, let start = startTime {
            timerSeconds = Int(Date().timeIntervalSince(start))
        }
    }
}
