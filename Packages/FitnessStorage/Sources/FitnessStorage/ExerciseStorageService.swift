import Foundation
import SwiftData
import FitnessCore
import Factory

@MainActor
public final class ExerciseStorageService: ExerciseStoring {
    private let context: ModelContext

    public init() {
        let container = Container.shared.modelContainer()
        self.context = ModelContext(container)
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

        let models = (try? context.fetch(descriptor)) ?? []
        return models.map { $0.toDomain() }
    }

    public func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        let categoryRaw = category.rawValue
        let deleteDescriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> {
                $0.workout?.id == workoutId && $0.category == categoryRaw
            }
        )

        if let existing = try? context.fetch(deleteDescriptor) {
            for model in existing {
                context.delete(model)
            }
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
        return try? context.fetch(descriptor).first
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("ExerciseStorageService: Failed to save context: \(error)")
        }
    }
}
