import Combine
import Foundation

class TimerService {
    @Published var timerSeconds: Int = 0
    private var timer: Timer?
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerSeconds += 1
            print("Timer ticking, timerSeconds: \(self?.timerSeconds ?? 0)")
        }
    }
    
    func resetAndStartTimer() {
        timerSeconds = 0
        startTimer()
        print("Timer reset and started, timerSeconds: \(timerSeconds)")
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        print("Timer stopped, timerSeconds: \(timerSeconds)")
    }
}
