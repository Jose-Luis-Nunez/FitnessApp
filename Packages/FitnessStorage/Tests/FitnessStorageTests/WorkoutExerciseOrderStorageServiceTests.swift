import Foundation
import SwiftData
import Testing
@_spi(PersistenceUI) @testable import FitnessStorage

@MainActor
@Suite("WorkoutExerciseOrderStorageService", .tags(.fast))
struct WorkoutExerciseOrderStorageServiceTests {
    @Test("A sequence is learned only after two consecutive cycles")
    func learnsAfterTwoConsecutiveCycles() throws {
        let fixture = try makeFixture()
        let sequence = [
            fixture.exerciseIds[0],
            fixture.exerciseIds[2],
            fixture.exerciseIds[4],
            fixture.exerciseIds[1],
            fixture.exerciseIds[3],
            fixture.exerciseIds[5],
            fixture.exerciseIds[6]
        ]

        record(sequence, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)

        var order = try #require(try fetchOrder(in: fixture))
        #expect(order.learnedExerciseIds.isEmpty)
        #expect(order.candidateExerciseIds == sequence)
        #expect(order.candidateRepeatCount == 1)
        #expect(order.pendingExerciseIds.isEmpty)

        record(sequence, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)

        order = try #require(try fetchOrder(in: fixture))
        #expect(order.learnedExerciseIds == sequence)
        #expect(order.candidateExerciseIds.isEmpty)
        #expect(order.candidateRepeatCount == 0)
    }

    @Test("One deviation does not replace a learned sequence")
    func oneDeviationDoesNotReplaceLearnedSequence() throws {
        let fixture = try makeFixture(count: 4)
        let learned = [
            fixture.exerciseIds[0],
            fixture.exerciseIds[2],
            fixture.exerciseIds[1],
            fixture.exerciseIds[3]
        ]
        learn(learned, in: fixture)

        let deviation = Array(learned.reversed())
        record(deviation, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)

        let order = try #require(try fetchOrder(in: fixture))
        #expect(order.learnedExerciseIds == learned)
        #expect(order.candidateExerciseIds == deviation)
        #expect(order.candidateRepeatCount == 1)
    }

    @Test("Two matching deviations replace the learned sequence")
    func twoMatchingDeviationsReplaceLearnedSequence() throws {
        let fixture = try makeFixture(count: 4)
        let learned = fixture.exerciseIds
        learn(learned, in: fixture)
        let replacement = Array(learned.reversed())

        learn(replacement, in: fixture)

        let order = try #require(try fetchOrder(in: fixture))
        #expect(order.learnedExerciseIds == replacement)
        #expect(order.candidateExerciseIds.isEmpty)
        #expect(order.candidateRepeatCount == 0)
    }

    @Test("Returning to the learned order clears a one-off candidate")
    func learnedOrderClearsCandidate() throws {
        let fixture = try makeFixture(count: 4)
        let learned = fixture.exerciseIds
        learn(learned, in: fixture)

        record(Array(learned.reversed()), in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)
        record(learned, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)

        let order = try #require(try fetchOrder(in: fixture))
        #expect(order.learnedExerciseIds == learned)
        #expect(order.candidateExerciseIds.isEmpty)
        #expect(order.candidateRepeatCount == 0)
    }

    @Test("A different observation replaces and resets the current candidate")
    func differentObservationResetsCandidate() throws {
        let fixture = try makeFixture(count: 4)
        let firstCandidate = [
            fixture.exerciseIds[1],
            fixture.exerciseIds[0],
            fixture.exerciseIds[2],
            fixture.exerciseIds[3]
        ]
        let secondCandidate = [
            fixture.exerciseIds[2],
            fixture.exerciseIds[0],
            fixture.exerciseIds[1],
            fixture.exerciseIds[3]
        ]

        record(firstCandidate, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)
        record(secondCandidate, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)

        let order = try #require(try fetchOrder(in: fixture))
        #expect(order.learnedExerciseIds.isEmpty)
        #expect(order.candidateExerciseIds == secondCandidate)
        #expect(order.candidateRepeatCount == 1)
    }

    @Test("Duplicate starts are ignored and an incomplete cycle keeps fallback order")
    func duplicateStartsAndPartialCycle() throws {
        let fixture = try makeFixture(count: 4)
        let partial = [fixture.exerciseIds[2], fixture.exerciseIds[0]]

        fixture.storage.recordStart(
            workoutId: fixture.workoutId,
            exerciseId: partial[0]
        )
        fixture.storage.recordStart(
            workoutId: fixture.workoutId,
            exerciseId: partial[0]
        )
        fixture.storage.recordStart(
            workoutId: fixture.workoutId,
            exerciseId: partial[1]
        )
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)

        let order = try #require(try fetchOrder(in: fixture))
        #expect(order.candidateExerciseIds == [
            fixture.exerciseIds[2],
            fixture.exerciseIds[0],
            fixture.exerciseIds[1],
            fixture.exerciseIds[3]
        ])
        #expect(order.candidateRepeatCount == 1)
    }

    @Test("Learning state is isolated per workout and persists across service instances")
    func stateIsWorkoutLocalAndPersistent() throws {
        let container = TestHelpers.makeInMemoryContainer()
        let first = try insertWorkoutWithExercises(count: 2, into: container)
        let second = try insertWorkoutWithExercises(count: 2, into: container)
        let storage = WorkoutExerciseOrderStorageService(container: container)

        storage.recordStart(workoutId: first.workoutId, exerciseId: first.exerciseIds[1])
        storage.recordStart(workoutId: second.workoutId, exerciseId: second.exerciseIds[0])

        let reloadedStorage = WorkoutExerciseOrderStorageService(container: container)
        reloadedStorage.finalizeCycle(workoutId: first.workoutId)

        let context = ModelContext(container)
        let orders = try context.fetch(FetchDescriptor<WorkoutExerciseOrderModel>())
        let firstOrder = try #require(orders.first { $0.workoutId == first.workoutId })
        let secondOrder = try #require(orders.first { $0.workoutId == second.workoutId })
        #expect(firstOrder.pendingExerciseIds.isEmpty)
        #expect(secondOrder.pendingExerciseIds == [second.exerciseIds[0]])
    }

    private func makeFixture(count: Int = 7) throws -> Fixture {
        let container = TestHelpers.makeInMemoryContainer()
        let inserted = try insertWorkoutWithExercises(count: count, into: container)
        return Fixture(
            container: container,
            storage: WorkoutExerciseOrderStorageService(container: container),
            workoutId: inserted.workoutId,
            exerciseIds: inserted.exerciseIds
        )
    }

    private func insertWorkoutWithExercises(
        count: Int,
        into container: ModelContainer
    ) throws -> (workoutId: UUID, exerciseIds: [UUID]) {
        let context = ModelContext(container)
        let workoutId = UUID()
        let workout = WorkoutModel(
            id: workoutId,
            name: "Order Test",
            selectedCategories: ["arms"],
            createdDate: .now,
            lastModified: .now
        )
        context.insert(workout)

        let ids = (0..<count).map { index in
            let id = UUID()
            context.insert(ExerciseModel(
                id: id,
                workoutId: workoutId,
                name: "Exercise \(index)",
                weight: 10,
                reps: 10,
                sets: 3,
                iconName: "defaultArmsIcon",
                category: "arms",
                sortOrder: index,
                isActive: true,
                workout: workout
            ))
            return id
        }
        try context.save()
        return (workoutId, ids)
    }

    private func record(_ ids: [UUID], in fixture: Fixture) {
        for id in ids {
            fixture.storage.recordStart(workoutId: fixture.workoutId, exerciseId: id)
        }
    }

    private func learn(_ ids: [UUID], in fixture: Fixture) {
        record(ids, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)
        record(ids, in: fixture)
        fixture.storage.finalizeCycle(workoutId: fixture.workoutId)
    }

    private func fetchOrder(in fixture: Fixture) throws -> WorkoutExerciseOrderModel? {
        let workoutId = fixture.workoutId
        let descriptor = FetchDescriptor<WorkoutExerciseOrderModel>(
            predicate: #Predicate<WorkoutExerciseOrderModel> {
                $0.workoutId == workoutId
            }
        )
        return try ModelContext(fixture.container).fetch(descriptor).first
    }

    private struct Fixture {
        let container: ModelContainer
        let storage: WorkoutExerciseOrderStorageService
        let workoutId: UUID
        let exerciseIds: [UUID]
    }
}
