import Testing
import Foundation
@testable import FitnessProfile

@Suite("RefreshScheduler Tests", .tags(.fast))
@MainActor
struct RefreshSchedulerTests {

    // MARK: - Failure marker lifecycle

    @Test func reportFailure_setsLastFailureAt() {
        let s = RefreshScheduler()
        #expect(s.lastFailureAt == nil)
        s.reportFailure()
        #expect(s.lastFailureAt != nil)
    }

    @Test func reportSuccess_clearsLastFailureAt() {
        let s = RefreshScheduler()
        s.reportFailure()
        #expect(s.lastFailureAt != nil)
        s.reportSuccess()
        #expect(s.lastFailureAt == nil)
    }

    // MARK: - shouldSkipAutoRefresh

    @Test func shouldSkipAutoRefresh_withoutFailure_returnsFalse() {
        let s = RefreshScheduler()
        #expect(s.shouldSkipAutoRefresh(staleThreshold: 60) == false)
    }

    @Test func shouldSkipAutoRefresh_recentFailure_returnsTrue() {
        let s = RefreshScheduler()
        s.reportFailure()
        // Immediately after failure: within threshold → skip
        #expect(s.shouldSkipAutoRefresh(staleThreshold: 60) == true)
    }

    @Test func shouldSkipAutoRefresh_oldFailure_returnsFalse() {
        let s = RefreshScheduler()
        s.reportFailure()
        // Pretend "now" is 120s after the failure → outside 60s threshold
        let later = Date().addingTimeInterval(120)
        #expect(s.shouldSkipAutoRefresh(staleThreshold: 60, now: later) == false)
    }

    @Test func shouldSkipAutoRefresh_failureExactlyAtThreshold_returnsFalse() {
        let s = RefreshScheduler()
        s.reportFailure()
        // Exactly at threshold → not strictly less than → don't skip
        let later = Date().addingTimeInterval(60)
        #expect(s.shouldSkipAutoRefresh(staleThreshold: 60, now: later) == false)
    }

    // MARK: - schedule cancels in-flight tasks

    @Test func schedule_cancelsPreviousTask() async {
        let s = RefreshScheduler()
        actor State {
            var firstCancelled = false
            var secondCompleted = false
            func markFirstCancelled() { firstCancelled = true }
            func markSecondCompleted() { secondCompleted = true }
        }
        let state = State()

        // First task: long-running, expects to be cancelled
        s.schedule {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)  // 500ms
            } catch {
                await state.markFirstCancelled()
            }
        }

        // Tiny pause so the first task has a chance to start
        try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        // Second task: fast, should complete
        await withCheckedContinuation { continuation in
            s.schedule {
                await state.markSecondCompleted()
                continuation.resume()
            }
        }

        // Wait for the first (cancelled) task to finish unwinding
        try? await Task.sleep(nanoseconds: 50_000_000)

        let firstCancelled = await state.firstCancelled
        let secondCompleted = await state.secondCompleted
        #expect(firstCancelled == true)
        #expect(secondCompleted == true)
    }
}
