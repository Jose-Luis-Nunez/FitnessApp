import Foundation
import SwiftData
import Testing
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI

/// Tests for `ExerciseCardModelView` and its variant resolver.
///
/// Two suites:
/// - `ResolveVariantTests` tests `FitnessCore.resolveCardVariant(...)` as a
///   pure function (no container setup needed). This is the logic the new
///   container calls live from `model.isCompleted`.
/// - `Bug1SanityTests` proves with a real in-memory `ModelContainer` that an
///   `ExerciseModel.isCompleted = true` mutation actually reroutes the variant
///   switch. This is the *data* side of the Bug-1 fix; the UI render proof comes
///   from the invariant test in `FitnessStorageTests/CoordinatorPersistsCompletionAfterFinishTests`
///   once T7 puts the view into use.

@MainActor
@Suite("resolveCardVariant — Logic", .tags(.integration))
struct ResolveVariantTests {

    @Test("isCompleted=true dominates: returns .completed regardless of the active set")
    func completedDominates() {
        let id = UUID()
        let v = resolveCardVariant(
            isCompleted: true,
            isActiveSetVisible: true,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(v == .completed)
    }

    @Test("Active set visible AND id matches: returns .active")
    func activeWhenMatched() {
        let id = UUID()
        let v = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(v == .active)
    }

    @Test("Active set visible but id mismatch: returns .idle")
    func idleWhenIdMismatch() {
        let v = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: UUID(),
            exerciseId: UUID()
        )
        #expect(v == .idle)
    }

    @Test("No active set visible: returns .idle (no active variant)")
    func idleWhenNoActiveSet() {
        let id = UUID()
        let v = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: false,
            activeExerciseId: id,
            exerciseId: id
        )
        #expect(v == .idle)
    }
}

@MainActor
@Suite("ExerciseCardModelView — Bug-1 Sanity (live model.isCompleted)", .tags(.integration))
struct Bug1SanityTests {

    /// Proves the data path: a mutation on `ExerciseModel.isCompleted` immediately
    /// changes the derived `CardVariant`. Before T5 the container ran on
    /// `viewModel.exercise.isCompleted` (a snapshot that had to be updated manually via
    /// `syncExercise(...)` — the Bug-1 source).
    @Test("model.isCompleted=true → resolveVariant flips from .idle to .completed")
    func variantFlipsOnMutation() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutModel.self, ExerciseModel.self,
            configurations: config
        )
        let ctx = ModelContext(container)

        let workoutId = UUID()
        let workout = WorkoutModel(
            id: workoutId,
            name: "W",
            selectedCategories: [MuscleCategoryGroup.chest.rawValue],
            createdDate: .now,
            lastModified: .now
        )
        ctx.insert(workout)

        let model = ExerciseModel(
            id: UUID(),
            workoutId: workoutId,
            name: "Bench",
            weight: 60,
            reps: 10,
            sets: 3,
            iconName: MuscleCategoryGroup.chest.defaultIconName,
            category: MuscleCategoryGroup.chest.rawValue,
            workout: workout
        )
        ctx.insert(model)
        try ctx.save()

        let initial = resolveCardVariant(
            isCompleted: model.isCompleted,
            isActiveSetVisible: false,
            activeExerciseId: nil,
            exerciseId: model.id
        )
        #expect(initial == .idle)

        model.isCompleted = true
        try ctx.save()

        let after = resolveCardVariant(
            isCompleted: model.isCompleted,
            isActiveSetVisible: false,
            activeExerciseId: nil,
            exerciseId: model.id
        )
        #expect(after == .completed)
    }
}
