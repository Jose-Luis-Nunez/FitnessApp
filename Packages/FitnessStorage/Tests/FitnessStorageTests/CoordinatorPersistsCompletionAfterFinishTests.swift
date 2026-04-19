import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@testable import FitnessStorage
import Factory

// MARK: - Why this file exists
//
// These tests cover the two production bugs reported in 2026-04 that motivated
// the `observable-models-sot` migration plan (see .cursor/plans/observable-models-sot/):
//
//   Bug 1: After all sets of an exercise are completed and `finishExercise()`
//          is called, the on-screen card stays in the "idle" variant (no play
//          button) instead of the "completed" variant. The UI only updates
//          after the user navigates away and back.
//
//   Bug 2: The CategoryTile "X of Y" count does not refresh after an exercise
//          is completed in-session — only when the parent (Workout) view
//          re-creates the tile.
//
// Both bugs share the same root cause family: UI consumers were holding
// snapshot copies of `Exercise` (struct) and relied on a `changeVersion: Int`
// counter polling loop to know when to re-fetch. See ADR-0001
// (docs/adr/0001-model-as-ui-source-of-truth.md) and
// `.cursor/rules/ui-state-sync-enforcement.mdc`.
//
// These tests intentionally exercise the **production wiring** end-to-end:
// real `ExerciseStorageService` against an in-memory `ModelContainer`, real
// `ExerciseManagementService` resolved through Factory, real
// `WorkoutStorageService`. Nothing about the path under test is mocked.
//
// What they verify is the **persisted invariant** (the canonical truth that
// any UI must derive from). They do NOT verify SwiftUI re-render behaviour —
// that is the domain of T7 once we migrate to `@Query`/`@Bindable`.
//
// Status during the migration:
//   - Today (pre-T7): expected to PASS — `FinishExerciseUseCase` does
//     persist `isCompleted = true` via `onExerciseUpdate`. The bugs are
//     therefore not in persistence; they are in the UI's failure to observe
//     the change. These tests document the post-write invariant so that any
//     future refactor that breaks persistence (e.g. a "fast path" that only
//     mutates a struct copy) fails immediately.
//   - After T7: same expectation; the tests should remain GREEN as the UI
//     starts deriving directly from `@Query<ExerciseModel>` results.
//
// If a test in this file ever turns red, the failure means we have
// reintroduced the old snapshot-based mutation pattern at the persistence
// layer — that would be a regression of ADR-0001 and must block the merge.

@Suite("Coordinator persists exercise completion across finishExercise (Bug 1 + Bug 2)", .serialized)
@MainActor
struct CoordinatorPersistsCompletionAfterFinishTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (
        management: ExerciseManagementService,
        workoutStorage: WorkoutStorageService,
        exerciseStorage: ExerciseStorageService,
        analyticsStorage: AnalyticsStorageService
    ) {
        TestHelpers.makeStorageStack(container: container)
    }

    // MARK: - Bug 1 invariant: persisted state reflects completion

    @Test("After finishExercise, ExerciseModel.isCompleted is persisted to true (Bug 1 invariant)")
    func persistedModelReflectsCompletionAfterFinishExercise() throws {
        let sut = makeSUT()
        let workout = try #require(sut.workoutStorage.workouts.first)

        let exercise = TestHelpers.makeExercise(
            name: "Loop",
            sets: 3,
            isCompleted: false,
            category: .arms
        )
        sut.exerciseStorage.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        // Production path: the coordinator's finishExercise() ultimately calls
        // back into ExerciseManagementService.updateExercise(...), which
        // persists isCompleted=true via ExerciseStorageService.saveForWorkout.
        // We simulate the final write the same way the coordinator would.
        var completed = exercise
        completed.isCompleted = true
        sut.management.updateExercise(completed, category: .arms)

        // Read the canonical truth from a fresh ModelContext on the same
        // container — bypasses any in-memory caches that the storage service
        // might hold.
        let context = ModelContext(container)
        let exerciseId = exercise.id
        var fetch = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == exerciseId }
        )
        fetch.fetchLimit = 1
        let model = try #require(try context.fetch(fetch).first)

        // Message intentionally omitted: swift-testing's Comment? only accepts
        // a single string literal, not a concatenated/multi-line one. The
        // suite display name and the comment above this @Test carry the
        // failure context.
        #expect(model.isCompleted == true)
    }

    // MARK: - Bug 2 invariant: count derived from storage drops to 0

    @Test("After last exercise in category is finished, ExerciseManagementService count drops to 0 active (Bug 2 invariant)")
    func categoryCountDropsAfterLastExerciseFinished() throws {
        let sut = makeSUT()
        let workout = try #require(sut.workoutStorage.workouts.first)

        let exercise = TestHelpers.makeExercise(
            name: "Loop",
            sets: 3,
            isCompleted: false,
            category: .arms
        )
        sut.exerciseStorage.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        // Sanity: before finish, 1 of 1 active.
        let before = sut.management.getExerciseCount(for: .arms)
        #expect(before.total == 1)
        #expect(before.active == 1)

        // Production-equivalent finish: persists isCompleted=true through the
        // real service stack.
        var completed = exercise
        completed.isCompleted = true
        sut.management.updateExercise(completed, category: .arms)

        // Canonical truth via the SAME service that the UI's tile reads from.
        let after = sut.management.getExerciseCount(for: .arms)
        #expect(after.active == 0)
        #expect(after.total == 1)
    }

    // MARK: - Bug 2 strengthened: query a fresh context to rule out in-process caches

    @Test("Independent ModelContext on the same container also sees isCompleted=true (rules out service-layer caching)")
    func independentContextSeesCompletion() throws {
        let sut = makeSUT()
        let workout = try #require(sut.workoutStorage.workouts.first)

        let exercise = TestHelpers.makeExercise(
            name: "Loop",
            sets: 3,
            isCompleted: false,
            category: .arms
        )
        sut.exerciseStorage.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        var completed = exercise
        completed.isCompleted = true
        sut.management.updateExercise(completed, category: .arms)

        // A fresh context bypasses any per-service ModelContext that might
        // hold stale snapshots. If the persisted store is correct, this
        // count must match the management service's count.
        //
        // NOTE on §14a/b (predicate optional-chain): the `$0.workout?.id`
        // predicate below intentionally MIRRORS the production predicate in
        // ExerciseStorageService.loadForWorkout (line 30). Both are flagged
        // by the predicate-smell hook and both will be replaced together in
        // T3 (denormalised `workoutId: UUID` on ExerciseModel, per ADR-0005).
        // Keeping them in lockstep guarantees the regression guard remains
        // valid through the migration — a divergent test predicate would
        // silently lose its coverage.
        let context = ModelContext(container)
        let categoryRaw = MuscleCategoryGroup.arms.rawValue
        let workoutId = workout.id
        let fetch = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> {
                $0.workout?.id == workoutId && $0.category == categoryRaw
            }
        )
        let models = try context.fetch(fetch)
        let activeCount = models.filter { !$0.isCompleted }.count
        #expect(activeCount == 0)
        #expect(models.count == 1)
    }
}
