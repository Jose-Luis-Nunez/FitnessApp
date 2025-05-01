import Foundation

class TimerService: ObservableObject {
    @Published var timerSeconds: Int = 0
    private var timer: Timer?

    func startTimer() {
        timerSeconds = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.timerSeconds += 1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerSeconds = 0
    }
}
