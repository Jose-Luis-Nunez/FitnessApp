import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessAnalytics
import Factory

// MARK: - Helpers

private func makeExercise(
    id: UUID = UUID(),
    sets: Int = 3,
    isCompleted: Bool = false
) -> Exercise {
    Exercise(
        id: id,
        name: "Curl",
        weight: 20,
        reps: 10,
        sets: sets,
        isCompleted: isCompleted,
        iconName: "defaultArmsIcon",
        category: .arms
    )
}

@MainActor
private final class MockAnalyticsStorageForCoord: AnalyticsStoring {
    func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {}
    func load(for exerciseId: UUID) -> [AnalyticsEntry] { [] }
}

@MainActor
private func makeCoordinator(
    activeSetVM: ActiveSetViewModel? = nil,
    onExerciseUpdate: @escaping (Exercise, MuscleCategoryGroup) -> Void = { _, _ in },
    onExerciseReset: @escaping (Exercise, MuscleCategoryGroup) -> Void = { _, _ in }
) -> (TrainingCoordinator, ActiveSetViewModel) {
    Container.shared.reset()
    let vm = activeSetVM ?? ActiveSetViewModel()
    let coordinator = TrainingCoordinator(
        findCategory: { _ in .arms },
        onExerciseUpdate: onExerciseUpdate,
        onExerciseReset: onExerciseReset,
        activeSetViewModel: vm,
        analyticsViewModel: AnalyticsViewModel(storageService: MockAnalyticsStorageForCoord())
    )
    return (coordinator, vm)
}

// MARK: - finishExercise

@Suite("finishExercise")
@MainActor
struct FinishExerciseTests {

    @Test func setsCurrentExerciseToNilAndIsTrainingActiveToFalse() {
        let (coordinator, _) = makeCoordinator()

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)
        #expect(coordinator.currentExercise != nil)
        #expect(coordinator.isTrainingActive == true)

        for _ in 0..<exercise.sets {
            coordinator.completeSet()
        }

        coordinator.finishExercise()

        #expect(coordinator.currentExercise == nil)
        #expect(coordinator.isTrainingActive == false)
    }

    @Test func callsOnExerciseUpdateWithIsCompletedTrue() {
        var receivedExercise: Exercise?
        var receivedCategory: MuscleCategoryGroup?

        let (coordinator, _) = makeCoordinator(
            onExerciseUpdate: { ex, cat in
                receivedExercise = ex
                receivedCategory = cat
            }
        )

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)

        for _ in 0..<3 {
            coordinator.completeSet()
        }

        coordinator.finishExercise()

        #expect(receivedExercise?.isCompleted == true)
        #expect(receivedCategory == .arms)
    }

    @Test func doesNotMarkCompletedWhenLastSetNotFinished() {
        var receivedExercise: Exercise?

        let (coordinator, _) = makeCoordinator(
            onExerciseUpdate: { ex, _ in receivedExercise = ex }
        )

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.completeSet()

        coordinator.finishExercise()

        #expect(receivedExercise?.isCompleted != true)
    }

    @Test func resetsActiveSetViewModelState() {
        let activeSetVM = ActiveSetViewModel()
        let (coordinator, _) = makeCoordinator(activeSetVM: activeSetVM)

        let exercise = makeExercise(sets: 1)
        coordinator.startTraining(for: exercise)
        coordinator.completeSet()
        coordinator.finishExercise()

        #expect(activeSetVM.currentExercise == nil)
        #expect(activeSetVM.setProgress.isEmpty)
        #expect(activeSetVM.isSetInProgress == false)
    }
}

// MARK: - Tracking observer

@Suite("tracking observer")
@MainActor
struct TrackingObserverTests {

    @Test func mapsTrackingCurrentExerciseToCoordinatorCurrentExercise() async throws {
        let (coordinator, _) = makeCoordinator()

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)

        try await Task.sleep(for: .milliseconds(100))

        #expect(coordinator.currentExercise?.id == exercise.id)
        #expect(coordinator.isTrainingActive == true)
    }
}

// MARK: - cancelTraining

@Suite("cancelTraining")
@MainActor
struct CancelTrainingTests {

    @Test func resetsCoordinatorState() {
        let (coordinator, _) = makeCoordinator()

        let exercise = makeExercise()
        coordinator.startTraining(for: exercise)
        coordinator.cancelTraining()

        #expect(coordinator.currentExercise == nil)
        #expect(coordinator.isTrainingActive == false)
    }
}

// MARK: - handleQuickDone

@Suite("handleQuickDone")
@MainActor
struct HandleQuickDoneTests {

    @Test func setsAllSetsCompletedAndLastSetCompleted() {
        let activeSetVM = ActiveSetViewModel()
        let (coordinator, _) = makeCoordinator(activeSetVM: activeSetVM)

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.handleQuickDone()

        #expect(activeSetVM.isLastSetCompleted == true)
        #expect(activeSetVM.setProgress.count == 3)
        #expect(activeSetVM.setProgress.allSatisfy { $0.status == .completedDone })
    }

    @Test func setsTrainingActiveAfterQuickDone() {
        let activeSetVM = ActiveSetViewModel()
        let (coordinator, _) = makeCoordinator(activeSetVM: activeSetVM)

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.handleQuickDone()

        #expect(coordinator.isTrainingActive == true)
    }

    @Test func bottomBarShowsFinishAfterQuickDone() {
        let activeSetVM = ActiveSetViewModel()
        let (coordinator, _) = makeCoordinator(activeSetVM: activeSetVM)

        let exercise = makeExercise(sets: 3)
        coordinator.startTraining(for: exercise)
        coordinator.handleQuickDone()

        let barVM = coordinator.createBottomActionBarViewModel(
            exercises: [exercise],
            hasActiveExercise: true
        )

        #expect(barVM.showFinishButton == true)
        #expect(barVM.showSetControls == false)
    }
}
