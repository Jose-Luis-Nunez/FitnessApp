import Foundation
import FitnessCore
import Factory
import os
import SwiftData

private let exerciseOrderLogger = Logger(
    subsystem: "FitnessStorage",
    category: "WorkoutExerciseOrderStorageService"
)

@MainActor
public final class WorkoutExerciseOrderStorageService: WorkoutExerciseOrderStoring {
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    public init(container: ModelContainer? = nil) {
        self.modelContainer = container ?? Container.shared.modelContainer()
    }

    public func recordStart(workoutId: UUID, exerciseId: UUID) {
        do {
            let order = try fetchOrCreateOrder(workoutId: workoutId)
            guard !order.pendingExerciseIds.contains(exerciseId) else { return }
            order.pendingExerciseIds.append(exerciseId)
            try context.save()
        } catch {
            context.rollback()
            exerciseOrderLogger.error(
                "Failed to record exercise \(exerciseId) for workout \(workoutId): \(error)"
            )
        }
    }

    public func finalizeCycle(workoutId: UUID) {
        do {
            guard let order = try fetchOrder(workoutId: workoutId) else { return }
            let availableIds = try activeExerciseIds(workoutId: workoutId)
            let availableSet = Set(availableIds)

            // Prune deleted/deactivated exercises from persisted state. A
            // reactivated exercise consequently returns through the normal
            // fallback placement until a later sequence confirms its rank.
            order.learnedExerciseIds = unique(
                order.learnedExerciseIds.filter { availableSet.contains($0) }
            )
            let prunedCandidate = unique(
                order.candidateExerciseIds.filter { availableSet.contains($0) }
            )
            if prunedCandidate != order.candidateExerciseIds {
                order.candidateRepeatCount = 0
            }
            order.candidateExerciseIds = prunedCandidate
            if prunedCandidate.isEmpty {
                order.candidateRepeatCount = 0
            }
            order.pendingExerciseIds = unique(
                order.pendingExerciseIds.filter { availableSet.contains($0) }
            )

            guard !order.pendingExerciseIds.isEmpty else {
                try context.save()
                return
            }

            let learnedBaseline = completedOrder(
                preferred: order.learnedExerciseIds,
                fallback: availableIds
            )
            let observation = completedOrder(
                preferred: order.pendingExerciseIds,
                fallback: learnedBaseline
            )

            advanceLearning(order, observation: observation, learnedBaseline: learnedBaseline)
            order.pendingExerciseIds = []
            try context.save()
        } catch {
            context.rollback()
            exerciseOrderLogger.error(
                "Failed to finalize exercise order for workout \(workoutId): \(error)"
            )
        }
    }

    private func advanceLearning(
        _ order: WorkoutExerciseOrderModel,
        observation: [UUID],
        learnedBaseline: [UUID]
    ) {
        guard observation != learnedBaseline || order.learnedExerciseIds.isEmpty else {
            order.candidateExerciseIds = []
            order.candidateRepeatCount = 0
            return
        }

        if observation == order.candidateExerciseIds {
            order.candidateRepeatCount += 1
        } else {
            order.candidateExerciseIds = observation
            order.candidateRepeatCount = 1
        }

        if order.candidateRepeatCount >= 2 {
            order.learnedExerciseIds = observation
            order.candidateExerciseIds = []
            order.candidateRepeatCount = 0
        }
    }

    private func activeExerciseIds(workoutId: UUID) throws -> [UUID] {
        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { model in
                model.workoutId == workoutId
            },
            sortBy: [
                SortDescriptor(\.category),
                SortDescriptor(\.sortOrder)
            ]
        )
        return try context.fetch(descriptor)
            .filter { $0.isActive ?? true }
            .map(\.id)
    }

    private func fetchOrder(workoutId: UUID) throws -> WorkoutExerciseOrderModel? {
        var descriptor = FetchDescriptor<WorkoutExerciseOrderModel>(
            predicate: #Predicate<WorkoutExerciseOrderModel> { order in
                order.workoutId == workoutId
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchOrCreateOrder(workoutId: UUID) throws -> WorkoutExerciseOrderModel {
        if let existing = try fetchOrder(workoutId: workoutId) {
            return existing
        }
        let order = WorkoutExerciseOrderModel(workoutId: workoutId)
        context.insert(order)
        return order
    }

    private func completedOrder(preferred: [UUID], fallback: [UUID]) -> [UUID] {
        unique(preferred + fallback)
    }

    private func unique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
