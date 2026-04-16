import Foundation
import os
import SwiftData
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "ExerciseStorageService")

@MainActor
public final class ExerciseStorageService: ExerciseStoring {
    private let context: ModelContext

    public init(container: ModelContainer? = nil) {
        let resolved = container ?? Container.shared.modelContainer()
        self.context = ModelContext(resolved)
        self.context.autosaveEnabled = true
    }

    public func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        let categoryRaw = category.rawValue
        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> {
                $0.workout?.id == workoutId && $0.category == categoryRaw
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

    public func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        let categoryRaw = category.rawValue
        let deleteDescriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> {
                $0.workout?.id == workoutId && $0.category == categoryRaw
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

        saveContext()
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

    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context: \(error)")
        }
    }
}
