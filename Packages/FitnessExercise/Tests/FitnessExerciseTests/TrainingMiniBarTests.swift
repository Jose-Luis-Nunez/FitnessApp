import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessTraining
import FitnessTestSupport

/// Stands in for the coordinator cache so the gating decision can be tested
/// without any training state or view involvement.
@MainActor
private final class StubCache: TrainingCoordinatorCaching {
    var activeTrainings: [ActiveTrainingTarget]

    init(activeTrainings: [ActiveTrainingTarget] = []) {
        self.activeTrainings = activeTrainings
    }

    func coordinator(for group: MuscleCategoryGroup) -> TrainingCoordinator {
        TrainingCoordinator(
            findCategory: { _ in group },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in }
        )
    }

    func findCoordinator(for exercise: Exercise) -> (TrainingCoordinator, MuscleCategoryGroup)? {
        nil
    }
}

@Suite("TrainingMiniBar", .tags(.fast))
@MainActor
struct TrainingMiniBarTests {

    private func target(_ name: String, _ group: MuscleCategoryGroup) -> ActiveTrainingTarget {
        ActiveTrainingTarget(
            exercise: FitnessTestSupport.makeExercise(name: name, category: group),
            group: group
        )
    }

    /// The mini bar is the way *back into* training, so it must not appear while
    /// the training sheet it would lead to is already open.
    @Test func targetsAreSuppressedWhileTheTrainingSheetIsPresented() {
        let cache = StubCache(activeTrainings: [target("Curl", .arms)])
        let router = AppRouter()
        router.replaceAll(with: [.home])
        router.presentTraining(exerciseId: UUID(), category: .arms)

        #expect(TrainingMiniBar.targets(router: router, cache: cache).isEmpty)
    }

    /// Only the workout drill-down carries the bar; the other tabs have no
    /// bottom-anchored chrome that expects the plate.
    @Test func targetsAreSuppressedOutsideTheWorkoutDrillDown() {
        let cache = StubCache(activeTrainings: [target("Curl", .arms)])
        let router = AppRouter()

        router.switchToProfile()
        #expect(TrainingMiniBar.targets(router: router, cache: cache).isEmpty)

        router.switchToAnalytics()
        #expect(TrainingMiniBar.targets(router: router, cache: cache).isEmpty)
    }

    @Test func targetsPassThroughOnTheCategoryScenes() {
        let running = [target("Curl", .arms), target("Bench", .chest)]
        let cache = StubCache(activeTrainings: running)
        let router = AppRouter()
        router.replaceAll(with: [.home])

        #expect(TrainingMiniBar.targets(router: router, cache: cache).count == 2)
    }
}
