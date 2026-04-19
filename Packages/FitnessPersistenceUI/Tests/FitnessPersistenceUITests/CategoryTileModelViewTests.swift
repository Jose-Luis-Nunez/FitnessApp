import Foundation
import SwiftData
import Testing
import FitnessCore
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI

/// Tests für `CategoryTileModelView`: bewiesen wird die Predicate-Logik gegen
/// einen echten in-memory `ModelContainer`. `@Query` selbst lässt sich nicht
/// out-of-View instanziieren, aber genau das gleiche Predicate über
/// `FetchDescriptor` zu fahren beweist die Daten-Schicht — der UI-Render-Beweis
/// wird vom invariant-Test in `FitnessStorageTests` getragen sobald T7 die View
/// einsetzt.

@MainActor
@Suite("CategoryTileModelView — Bug-2 Predicate gegen ExerciseModel.workoutId")
struct CategoryTileModelViewTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WorkoutModel.self, ExerciseModel.self,
            configurations: config
        )
    }

    private func makeWorkout(id: UUID = UUID()) -> WorkoutModel {
        WorkoutModel(
            id: id,
            name: "W",
            selectedCategories: [MuscleCategoryGroup.chest.rawValue],
            createdDate: .now,
            lastModified: .now
        )
    }

    private func insertExercise(
        in ctx: ModelContext,
        workoutId: UUID,
        workout: WorkoutModel,
        category: MuscleCategoryGroup = .arms,
        isCompleted: Bool = false,
        sortOrder: Int = 0
    ) -> ExerciseModel {
        let m = ExerciseModel(
            id: UUID(),
            workoutId: workoutId,
            name: "E\(sortOrder)",
            weight: 60,
            reps: 10,
            sets: 3,
            isCompleted: isCompleted,
            iconName: category.defaultIconName,
            category: category.rawValue,
            sortOrder: sortOrder,
            workout: workout
        )
        ctx.insert(m)
        return m
    }

    @Test("Total + active count matches data scoped to (workoutId, category)")
    func countMatchesData() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let workoutId = UUID()
        let workout = makeWorkout(id: workoutId)
        ctx.insert(workout)

        // 3 in 'arms', 1 davon completed
        for i in 0..<3 {
            _ = insertExercise(
                in: ctx,
                workoutId: workoutId,
                workout: workout,
                category: .arms,
                isCompleted: i == 0,
                sortOrder: i
            )
        }
        // 1 in 'chest' (sollte NICHT mitgezählt werden)
        _ = insertExercise(
            in: ctx,
            workoutId: workoutId,
            workout: workout,
            category: .chest,
            isCompleted: false,
            sortOrder: 0
        )
        try ctx.save()

        let raw = MuscleCategoryGroup.arms.rawValue
        let wid = workoutId
        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { exercise in
                exercise.workoutId == wid && exercise.category == raw
            }
        )
        let fetched = try ctx.fetch(descriptor)

        let total = fetched.count
        let active = fetched.lazy.filter { !$0.isCompleted }.count
        let completed = total - active

        #expect(total == 3)
        #expect(active == 2)
        #expect(completed == 1)
    }

    @Test("Predicate isoliert nach workoutId: Übungen aus anderem Workout zählen nicht")
    func predicateIsolatesByWorkout() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let workoutA = makeWorkout()
        let workoutB = makeWorkout()
        ctx.insert(workoutA)
        ctx.insert(workoutB)

        _ = insertExercise(in: ctx, workoutId: workoutA.id, workout: workoutA, category: .arms, sortOrder: 0)
        _ = insertExercise(in: ctx, workoutId: workoutA.id, workout: workoutA, category: .arms, sortOrder: 1)
        _ = insertExercise(in: ctx, workoutId: workoutB.id, workout: workoutB, category: .arms, sortOrder: 0)
        try ctx.save()

        let raw = MuscleCategoryGroup.arms.rawValue
        let widA = workoutA.id
        let widB = workoutB.id

        let countA = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.workoutId == widA && $0.category == raw }
        )).count
        let countB = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.workoutId == widB && $0.category == raw }
        )).count

        #expect(countA == 2)
        #expect(countB == 1)
    }

    /// Beweist den Bug-2-Daten-Pfad: Eine Mutation auf `ExerciseModel.isCompleted`
    /// ändert den Active-Count für die Kategorie sofort — auch ohne dass eine
    /// View `refreshExercises()` ruft. Das ist genau was `@Query` live im Render
    /// in der UI tut.
    @Test("Bug-2 Sanity: completed-Mutation senkt active-count im selben Context")
    func activeCountDropsAfterMutation() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let workoutId = UUID()
        let workout = makeWorkout(id: workoutId)
        ctx.insert(workout)

        let exercise = insertExercise(
            in: ctx,
            workoutId: workoutId,
            workout: workout,
            category: .arms,
            isCompleted: false
        )
        try ctx.save()

        let raw = MuscleCategoryGroup.arms.rawValue
        let wid = workoutId
        let activeOnly = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { ex in
                ex.workoutId == wid && ex.category == raw && !ex.isCompleted
            }
        )

        #expect(try ctx.fetch(activeOnly).count == 1)

        exercise.isCompleted = true
        try ctx.save()

        #expect(try ctx.fetch(activeOnly).count == 0)
    }

    @Test("Leeres Workout: Predicate liefert leere Liste, total/active == 0")
    func emptyWorkoutHasZeroCount() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        let workoutId = UUID()
        let workout = makeWorkout(id: workoutId)
        ctx.insert(workout)
        try ctx.save()

        let raw = MuscleCategoryGroup.legs.rawValue
        let wid = workoutId
        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.workoutId == wid && $0.category == raw }
        )
        let fetched = try ctx.fetch(descriptor)
        #expect(fetched.isEmpty)
    }
}
