import Testing
import Foundation
import FitnessCore
@testable import FitnessTraining
import FitnessTestSupport

@Suite("ActiveSetViewModel")
@MainActor
struct ActiveSetViewModelTests {

    private func makeSUT() -> ActiveSetViewModel {
        ActiveSetViewModel()
    }

    private func makeExercise(sets: Int = 3, reps: Int = 10, weight: Double = 60) -> Exercise {
        FitnessTestSupport.makeExercise(name: "Curl", weight: weight, reps: reps, sets: sets, category: .arms)
    }

    // MARK: - Initial State

    @Test func initialStateIsIdle() {
        let sut = makeSUT()
        #expect(sut.currentExercise == nil)
        #expect(sut.setProgress.isEmpty)
        #expect(sut.currentSet == 0)
        #expect(sut.isSetInProgress == false)
        #expect(sut.isLastSetCompleted == false)
        #expect(sut.quickDoneModeActive == false)
        #expect(sut.quickDoneAllCompleted == false)
    }

    // MARK: - startSet

    @Test func startSetInitializesTrackingState() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3)

        sut.startSet(for: exercise, category: .arms)

        #expect(sut.currentExercise?.id == exercise.id)
        #expect(sut.setProgress.count == 3)
        #expect(sut.currentSet == 0)
        #expect(sut.isSetInProgress == true)
        #expect(sut.isLastSetCompleted == false)
        #expect(sut.category == .arms)
        #expect(sut.originalCategory == .arms)
    }

    @Test func startSetCreatesNotStartedProgress() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)

        sut.startSet(for: exercise, category: .arms)

        for sp in sut.setProgress {
            #expect(sp.status == .notStarted)
            #expect(sp.currentReps == 10)
            #expect(sp.weight == 60)
        }
    }

    @Test func startSetPreservesOriginalCategory() {
        let sut = makeSUT()
        let exercise = makeExercise()

        sut.startSet(for: exercise, category: .arms)
        sut.startSet(for: exercise, category: .chest)

        #expect(sut.originalCategory == .arms)
    }

    // MARK: - completeCurrentSet

    @Test func completeCurrentSetMarksSetAsCompletedDone() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3)
        sut.startSet(for: exercise, category: .arms)

        sut.completeCurrentSet()

        #expect(sut.setProgress[0].status == .completedDone)
        #expect(sut.currentSet == 1)
        #expect(sut.isSetInProgress == false)
    }

    @Test func completeAllSetsMarksLastSetCompleted() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 2)
        sut.startSet(for: exercise, category: .arms)

        sut.completeCurrentSet()
        sut.startNextSet()
        sut.completeCurrentSet()

        #expect(sut.isLastSetCompleted == true)
        #expect(sut.currentSet == 2)
    }

    @Test func completeCurrentSetDoesNothingWithoutExercise() {
        let sut = makeSUT()
        sut.completeCurrentSet()
        #expect(sut.currentSet == 0)
    }

    @Test func completeCurrentSetDoesNothingWhenAllSetsComplete() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 1)
        sut.startSet(for: exercise, category: .arms)

        sut.completeCurrentSet()
        let currentSetAfterFirst = sut.currentSet
        sut.completeCurrentSet()

        #expect(sut.currentSet == currentSetAfterFirst)
    }

    // MARK: - startNextSet

    @Test func startNextSetAdvancesActiveSetIndex() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3)
        sut.startSet(for: exercise, category: .arms)

        sut.completeCurrentSet()
        sut.startNextSet()

        #expect(sut.activeSetIndex == 1)
        #expect(sut.isSetInProgress == true)
    }

    @Test func startNextSetDoesNothingWhenAllSetsComplete() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 1)
        sut.startSet(for: exercise, category: .arms)
        sut.completeCurrentSet()

        sut.startNextSet()

        #expect(sut.isSetInProgress == false)
    }

    // MARK: - updateCurrentReps

    @Test func updateCurrentRepsMarksLessWhenBelowTarget() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)
        sut.startSet(for: exercise, category: .arms)

        sut.updateCurrentReps(8, 50)

        #expect(sut.setProgress[0].status == .completedLess)
        #expect(sut.setProgress[0].currentReps == 8)
        #expect(sut.setProgress[0].weight == 50)
        #expect(sut.currentSet == 1)
    }

    @Test func updateCurrentRepsMarksMoreWhenAboveTarget() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)
        sut.startSet(for: exercise, category: .arms)

        sut.updateCurrentReps(12, 60)

        #expect(sut.setProgress[0].status == .completedMore)
    }

    @Test func updateCurrentRepsAtPendingEditIndex() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)
        sut.startSet(for: exercise, category: .arms)
        sut.completeCurrentSet()
        sut.startNextSet()

        sut.pendingEditIndex = 0
        sut.updateCurrentReps(8, 55)

        #expect(sut.setProgress[0].status == .completedLess)
        #expect(sut.setProgress[0].currentReps == 8)
        #expect(sut.pendingEditIndex == nil)
        #expect(sut.didJustEditSet == true)
    }

    @Test func updateCurrentRepsCompletesExerciseWhenAllSetsDone() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 1, reps: 10, weight: 60)
        sut.startSet(for: exercise, category: .arms)

        sut.updateCurrentReps(12, 65)

        #expect(sut.isLastSetCompleted == true)
        #expect(sut.didEditCompleteSet == true)
    }

    @Test func updateCurrentRepsAtNonActiveEditIndexDoesNotAdvanceCurrentSet() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)
        sut.startSet(for: exercise, category: .arms)

        sut.completeCurrentSet()
        sut.startNextSet()
        sut.completeCurrentSet()
        sut.startNextSet()
        // activeSetIndex == 2, currentSet == 2

        // Edit set 0 (an older set, not the active one)
        sut.pendingEditIndex = 0
        sut.updateCurrentReps(8, 55)

        // currentSet must NOT advance because we edited an older set
        #expect(sut.currentSet == 2)
        #expect(sut.setProgress[0].status == .completedLess)
        #expect(sut.setProgress[0].currentReps == 8)
        #expect(sut.didJustEditSet == true)
        #expect(sut.pendingEditIndex == nil)
    }

    @Test func updateCurrentRepsAtActiveEditIndexAdvancesCurrentSet() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)
        sut.startSet(for: exercise, category: .arms)

        sut.completeCurrentSet()
        sut.startNextSet()
        // activeSetIndex == 1, currentSet == 1

        // Edit the active set (index 1)
        sut.pendingEditIndex = 1
        sut.updateCurrentReps(12, 65)

        // currentSet MUST advance because we edited the active set
        #expect(sut.currentSet == 2)
        #expect(sut.setProgress[1].status == .completedMore)
        #expect(sut.didJustEditSet == true)
        #expect(sut.pendingEditIndex == nil)
    }

    // MARK: - finishExercise

    @Test func finishExerciseResetsAllState() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startSet(for: exercise, category: .arms)
        sut.completeCurrentSet()

        sut.finishExercise()

        #expect(sut.currentExercise == nil)
        #expect(sut.setProgress.isEmpty)
        #expect(sut.currentSet == 0)
        #expect(sut.isSetInProgress == false)
        #expect(sut.isLastSetCompleted == false)
        #expect(sut.quickDoneModeActive == false)
        #expect(sut.quickDoneAllCompleted == false)
    }

    // MARK: - resetProgress

    @Test func resetProgressClearsTrackingButKeepsEditingState() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startSet(for: exercise, category: .arms)
        sut.completeCurrentSet()

        sut.resetProgress()

        #expect(sut.currentExercise == nil)
        #expect(sut.setProgress.isEmpty)
        #expect(sut.quickDoneAllCompleted == false)
    }

    // MARK: - cancelActiveSet

    @Test func cancelActiveSetClearsAllState() {
        let sut = makeSUT()
        let exercise = makeExercise()
        sut.startSet(for: exercise, category: .arms)
        sut.completeCurrentSet()

        sut.cancelActiveSet()

        #expect(sut.currentExercise == nil)
        #expect(sut.setProgress.isEmpty)
        #expect(sut.timerSeconds == 0)
        #expect(sut.didEditCompleteSet == false)
    }

    // MARK: - Quick Done

    @Test func startQuickDoneMarksAllSetsCompletedDone() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3)

        sut.startQuickDone(for: exercise, category: .arms)

        #expect(sut.setProgress.count == 3)
        #expect(sut.setProgress.allSatisfy { $0.status == .completedDone })
        #expect(sut.quickDoneAllCompleted == true)
        #expect(sut.isLastSetCompleted == true)
        #expect(sut.timerSeconds == 0)
    }

    @Test func processQuickDoneCompletesIndividualSet() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3)
        sut.startSet(for: exercise, category: .arms)

        sut.processQuickDone(at: 0)

        #expect(sut.setProgress[0].status == .completedDone)
        #expect(sut.setProgress[1].status == .notStarted)
    }

    @Test func processQuickDoneSkipsAlreadyCompletedSet() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 2)
        sut.startSet(for: exercise, category: .arms)

        sut.processQuickDone(at: 0)
        let firstId = sut.setProgress[0].id
        sut.processQuickDone(at: 0)

        #expect(sut.setProgress[0].id == firstId)
    }

    @Test func processQuickDoneAllSetsTriggersCompletion() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 2)
        sut.startSet(for: exercise, category: .arms)

        sut.processQuickDone(at: 0)
        sut.processQuickDone(at: 1)

        #expect(sut.quickDoneAllCompleted == true)
        #expect(sut.isLastSetCompleted == true)
    }

    @Test func completeAllQuickDoneCompletesRemainingNotStartedSets() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3)
        sut.startSet(for: exercise, category: .arms)

        sut.processQuickDone(at: 0)
        sut.completeAllQuickDone()

        #expect(sut.setProgress.allSatisfy { $0.status == .completedDone })
        #expect(sut.quickDoneAllCompleted == true)
    }

    // MARK: - Timer Integration

    @Test(.timeLimit(.minutes(1)))
    func timerSecondsReflectsTimerServiceTicks() async throws {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3)
        sut.startSet(for: exercise, category: .arms)

        // startSet calls resetAndStartTimer, and the VM's polling loop
        // propagates timerService.timerSeconds -> sut.timerSeconds.
        // Wait for at least 1 second of real elapsed time so the
        // TimerService's internal tick loop publishes a non-zero value.
        try await waitUntil(timeout: .seconds(3)) { sut.timerSeconds >= 1 }

        #expect(sut.timerSeconds >= 1)
    }

    // MARK: - Editing

    @Test func startEditingSetPopulatesEditingState() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)
        sut.startSet(for: exercise, category: .arms)
        sut.completeCurrentSet()

        sut.startEditingSet(index: 0, mode: .less)

        #expect(sut.isEditing == true)
        #expect(sut.pendingEditIndex == 0)
        #expect(sut.editMode == .less)
        #expect(sut.repsInput == "10")
    }

    @Test func resetEditingStateClearsInputs() {
        let sut = makeSUT()
        sut.repsInput = "12"
        sut.weightInput = "65"

        sut.resetEditingState()

        #expect(sut.repsInput.isEmpty)
        #expect(sut.weightInput.isEmpty)
    }

    // MARK: - formatTime

    @Test func formatTimeReturnsCorrectString() {
        let sut = makeSUT()
        #expect(sut.formatTime(seconds: 0) == "00:00")
        #expect(sut.formatTime(seconds: 65) == "01:05")
        #expect(sut.formatTime(seconds: 3600) == "60:00")
    }

    // MARK: - Full Set Lifecycle

    @Test func fullThreeSetLifecycle() {
        let sut = makeSUT()
        let exercise = makeExercise(sets: 3, reps: 10, weight: 60)

        sut.startSet(for: exercise, category: .arms)
        #expect(sut.isSetInProgress == true)

        sut.completeCurrentSet()
        #expect(sut.currentSet == 1)
        #expect(sut.isSetInProgress == false)

        sut.startNextSet()
        #expect(sut.isSetInProgress == true)

        sut.completeCurrentSet()
        #expect(sut.currentSet == 2)

        sut.startNextSet()
        sut.completeCurrentSet()
        #expect(sut.currentSet == 3)
        #expect(sut.isLastSetCompleted == true)
    }
}
