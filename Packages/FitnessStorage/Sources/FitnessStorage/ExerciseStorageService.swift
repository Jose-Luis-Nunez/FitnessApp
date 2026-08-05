import Foundation
import Observation
import os
import SwiftData
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "ExerciseStorageService")

@Observable
@MainActor
public final class ExerciseStorageService: ExerciseStoring {
    // Retain the CONTAINER, not just its mainContext — `mainContext` does not
    // strongly hold its container, so storing only the context lets a
    // caller-owned container deallocate and the store vanish under us.
    @ObservationIgnored
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    public init(container: ModelContainer? = nil) {
        self.modelContainer = container ?? Container.shared.modelContainer()
    }

    public func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        let categoryRaw = category.rawValue
        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> {
                $0.workoutId == workoutId && $0.category == categoryRaw
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        do {
            let models = try context.fetch(descriptor)
            return models.map { $0.toDomain() }
        } catch {
            logger.error("Failed to fetch exercises for workout \(workoutId): \(error)")
            return []
        }
    }

    public func loadWorkoutExercises(for workoutId: UUID) throws -> [Exercise] {
        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.workoutId == workoutId },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        let modelsByCategory = Dictionary(
            grouping: try context.fetch(descriptor),
            by: { MuscleCategoryGroup(rawValue: $0.category) ?? .arms }
        )
        return MuscleCategoryGroup.allCases.flatMap { category in
            (modelsByCategory[category] ?? []).map { $0.toDomain() }
        }
    }

    public func exerciseCountsByWorkout() -> [UUID: Int] {
        do {
            let models = try context.fetch(FetchDescriptor<ExerciseModel>())
            return models.reduce(into: [:]) { counts, model in
                guard let workoutId = model.workoutId else { return }
                counts[workoutId, default: 0] += 1
            }
        } catch {
            logger.error("Failed to fetch exercise counts by workout: \(error)")
            return [:]
        }
    }

    public func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        let categoryRaw = category.rawValue
        let deleteDescriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> {
                $0.workoutId == workoutId && $0.category == categoryRaw
            }
        )

        do {
            let existing = try context.fetch(deleteDescriptor)
            for model in existing {
                context.delete(model)
            }
        } catch {
            logger.error("Failed to fetch exercises for deletion: \(error)")
        }

        let workoutModel = fetchWorkoutModel(id: workoutId)

        for (index, exercise) in exercises.enumerated() {
            let model = ExerciseModel.from(exercise, sortOrder: index, workout: workoutModel)
            context.insert(model)
        }

        _ = saveContext()
    }

    public func updateExercise(_ exercise: Exercise) {
        let id = exercise.id
        var descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == id }
        )
        descriptor.fetchLimit = 1

        do {
            guard let model = try context.fetch(descriptor).first else {
                logger.error("updateExercise: no ExerciseModel found for id \(id)")
                return
            }
            let becameInactive = (model.isActive ?? true) && !exercise.isActive
            if becameInactive, let workoutId = model.workoutId {
                try removeFromLearnedOrder(exerciseId: id, workoutId: workoutId)
            }
            model.update(from: exercise)
            _ = saveContext()
        } catch {
            logger.error("Failed to update exercise \(id): \(error)")
        }
    }

    private func fetchWorkoutModel(id: UUID) -> WorkoutModel? {
        var descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("Failed to fetch workout model \(id): \(error)")
            return nil
        }
    }

    /// Deactivation makes an exercise unknown to the learned flat-list order
    /// immediately. If it is later reactivated, the resolver therefore places
    /// it behind all still-learned exercises using the normal fallback order.
    private func removeFromLearnedOrder(exerciseId: UUID, workoutId: UUID) throws {
        var descriptor = FetchDescriptor<WorkoutExerciseOrderModel>(
            predicate: #Predicate<WorkoutExerciseOrderModel> {
                $0.workoutId == workoutId
            }
        )
        descriptor.fetchLimit = 1
        guard let order = try context.fetch(descriptor).first else { return }

        order.pendingExerciseIds.removeAll { $0 == exerciseId }
        order.learnedExerciseIds.removeAll { $0 == exerciseId }
        if order.candidateExerciseIds.contains(exerciseId) {
            order.candidateExerciseIds = []
            order.candidateRepeatCount = 0
        }
    }

    @discardableResult
    private func saveContext() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            logger.error("Failed to save context: \(error)")
            return false
        }
    }
}
