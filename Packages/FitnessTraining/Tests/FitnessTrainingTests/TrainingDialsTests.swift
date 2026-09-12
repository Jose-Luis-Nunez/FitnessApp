import Testing
@testable import FitnessTraining

@Suite("Training dials", .tags(.fast))
struct TrainingDialsTests {
    @Test("Minute progress sweeps 0..<1 and restarts at every minute boundary")
    func minuteProgressWraps() {
        #expect(TrainingTimerPill.minuteProgress(seconds: 0) == 0)
        #expect(TrainingTimerPill.minuteProgress(seconds: 30) == 0.5)
        #expect(TrainingTimerPill.minuteProgress(seconds: 59) == 59.0 / 60.0)
        #expect(TrainingTimerPill.minuteProgress(seconds: 60) == 0)
        #expect(TrainingTimerPill.minuteProgress(seconds: 61) == 1.0 / 60.0)
        #expect(TrainingTimerPill.minuteProgress(seconds: 125) == 5.0 / 60.0)
    }

    @Test("Negative timer readings clamp to the start of the minute")
    func minuteProgressClampsNegative() {
        #expect(TrainingTimerPill.minuteProgress(seconds: -7) == 0)
    }
}
