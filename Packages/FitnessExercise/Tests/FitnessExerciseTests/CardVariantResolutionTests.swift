import Testing
import Foundation
@testable import FitnessExercise
import FitnessCore
import FitnessTraining
import FitnessTestSupport
import Factory

// MARK: - resolveVariant Unit Tests

@Suite("resolveVariant", .tags(.fast))
struct ResolveVariantTests {

    @Test func completedExerciseAlwaysReturnsCompleted() {
        let id = UUID()
        let variant = resolveCardVariant(
            isCompleted: true,
            isActiveSetVisible: true,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(variant == .completed)
    }

    @Test func activeSetVisibleWithMatchingIdReturnsActive() {
        let id = UUID()
        let variant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(variant == .active)
    }

    @Test func activeSetVisibleWithDifferentIdReturnsIdle() {
        let variant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: UUID(),
            exerciseId: UUID()
        )
        #expect(variant == .idle)
    }

    @Test func activeSetNotVisibleReturnsIdleEvenWhenIdsMatch() {
        let id = UUID()
        let variant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: false,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(variant == .idle)
    }

    @Test func activeSetVisibleWithNilActiveIdReturnsIdle() {
        let variant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: nil,
            exerciseId: UUID()
        )
        #expect(variant == .idle)
    }

    @Test func completedTakesPriorityOverActive() {
        let id = UUID()
        let variant = resolveCardVariant(
            isCompleted: true,
            isActiveSetVisible: true,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(variant == .completed)
    }
}

// MARK: - Multi-Training Integration Tests

@Suite("Multi-training card resolution", .tags(.fast))
@MainActor
struct MultiTrainingCardResolutionTests {

    init() {
        Container.shared.reset()
    }

    @Test func selectionViewShowsAllInProgressAsIdle() {
        let cache = TrainingCoordinatorCache()
        let armsCoord = cache.coordinator(for: .arms)
        let chestCoord = cache.coordinator(for: .chest)

        let curl = makeExercise(name: "Curl", category: .arms)
        let bench = makeExercise(name: "Bench", category: .chest)

        armsCoord.startTraining(for: curl)
        chestCoord.startTraining(for: bench)

        #expect(armsCoord.isExerciseInProgress(curl.id))
        #expect(chestCoord.isExerciseInProgress(bench.id))

        let curlVariant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: false,
            activeExerciseId: armsCoord.activeSetViewModel.currentExercise?.id,
            exerciseId: curl.id
        )
        let benchVariant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: false,
            activeExerciseId: chestCoord.activeSetViewModel.currentExercise?.id,
            exerciseId: bench.id
        )

        #expect(curlVariant == .idle)
        #expect(benchVariant == .idle)
    }

    @Test func trainingViewShowsFocusedExerciseAsActive() {
        let cache = TrainingCoordinatorCache()
        let armsCoord = cache.coordinator(for: .arms)
        let chestCoord = cache.coordinator(for: .chest)

        let curl = makeExercise(name: "Curl", category: .arms)
        let bench = makeExercise(name: "Bench", category: .chest)

        armsCoord.startTraining(for: curl)
        chestCoord.startTraining(for: bench)

        let curlVariant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: armsCoord.activeSetViewModel.currentExercise?.id,
            exerciseId: curl.id
        )
        let benchVariant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: armsCoord.activeSetViewModel.currentExercise?.id,
            exerciseId: bench.id
        )

        #expect(curlVariant == .active)
        #expect(benchVariant == .idle)
    }

    @Test func cancelledTrainingDoesNotAffectOtherCategory() {
        let cache = TrainingCoordinatorCache()
        let armsCoord = cache.coordinator(for: .arms)
        let chestCoord = cache.coordinator(for: .chest)

        let curl = makeExercise(name: "Curl", category: .arms)
        let bench = makeExercise(name: "Bench", category: .chest)

        armsCoord.startTraining(for: curl)
        chestCoord.startTraining(for: bench)

        armsCoord.cancelTraining()

        #expect(!armsCoord.isExerciseInProgress(curl.id))
        #expect(chestCoord.isExerciseInProgress(bench.id))

        let benchVariant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: false,
            activeExerciseId: chestCoord.activeSetViewModel.currentExercise?.id,
            exerciseId: bench.id
        )

        #expect(benchVariant == .idle)
    }

    @Test func multipleExercisesInSameCategoryAllResolveIdle() {
        let cache = TrainingCoordinatorCache()
        let armsCoord = cache.coordinator(for: .arms)

        let curl = makeExercise(name: "Curl", category: .arms)
        let hammer = makeExercise(name: "Hammer Curl", category: .arms)

        armsCoord.startTraining(for: curl)
        armsCoord.startTraining(for: hammer)

        let curlVariant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: false,
            activeExerciseId: armsCoord.activeSetViewModel.currentExercise?.id,
            exerciseId: curl.id
        )
        let hammerVariant = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: false,
            activeExerciseId: armsCoord.activeSetViewModel.currentExercise?.id,
            exerciseId: hammer.id
        )

        #expect(curlVariant == .idle)
        #expect(hammerVariant == .idle)
        #expect(armsCoord.isExerciseInProgress(curl.id))
        #expect(armsCoord.isExerciseInProgress(hammer.id))
    }
}
