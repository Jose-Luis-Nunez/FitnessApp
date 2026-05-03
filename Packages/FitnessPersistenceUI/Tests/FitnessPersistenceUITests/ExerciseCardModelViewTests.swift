import Foundation
import SwiftData
import Testing
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI

/// Tests für `ExerciseCardModelView` und seinen Variant-Resolver.
///
/// Zwei Suites:
/// - `ResolveVariantTests` testet `FitnessCore.resolveCardVariant(...)` als
///   pure Funktion (keine Container-Setup nötig). Das ist die Logik die der neue
///   Container live aus `model.isCompleted` aufruft.
/// - `Bug1SanityTests` beweist mit echtem in-memory `ModelContainer`, dass
///   `ExerciseModel.isCompleted = true` mutation den Variant-Switch tatsächlich
///   umlenkt. Das ist die *Daten*-Seite des Bug-1-Fix; der UI-Render-Beweis kommt
///   aus dem invariant-Test in `FitnessStorageTests/CoordinatorPersistsCompletionAfterFinishTests`
///   sobald T7 die View einsetzt.

@MainActor
@Suite("resolveCardVariant — Logik", .tags(.integration))
struct ResolveVariantTests {

    @Test("isCompleted=true dominiert: liefert .completed unabhängig vom Active-Set")
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

    @Test("Active-Set sichtbar UND id matcht: liefert .active")
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

    @Test("Active-Set sichtbar aber id mismatch: liefert .idle")
    func idleWhenIdMismatch() {
        let v = resolveCardVariant(
            isCompleted: false,
            isActiveSetVisible: true,
            activeExerciseId: UUID(),
            exerciseId: UUID()
        )
        #expect(v == .idle)
    }

    @Test("Kein Active-Set sichtbar: liefert .idle (keine Active-Variante)")
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

    /// Beweist den Daten-Pfad: Eine Mutation auf `ExerciseModel.isCompleted` ändert
    /// den abgeleiteten `CardVariant` sofort. Vor T5 lief der Container über
    /// `viewModel.exercise.isCompleted` (ein Snapshot der manuell via
    /// `syncExercise(...)` aktualisiert werden musste — Bug-1-Quelle).
    @Test("model.isCompleted=true → resolveVariant flippt von .idle auf .completed")
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
