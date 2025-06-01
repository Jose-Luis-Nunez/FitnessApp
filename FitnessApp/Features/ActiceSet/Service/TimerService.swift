import Foundation

class TimerService: ObservableObject {
    @Published var timerSeconds: Int = 0
    private var timer: Timer?

    func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerSeconds += 1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func resetAndStartTimer() {
        stopTimer()
        timerSeconds = 0
        startTimer()
    }
}
