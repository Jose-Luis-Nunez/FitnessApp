import Foundation
import SwiftData
import Testing
import FitnessCore
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI

/// Smoke-tests that prove the new package can:
/// 1. import `FitnessStorage` via `@_spi(PersistenceUI)` — i.e. the SPI
///    marker is wired correctly and the `@Model` macro plays well with it.
/// 2. spin up an in-memory `ModelContainer` over the two model types
///    `FitnessPersistenceUI` is allowed to see (`ExerciseModel`,
///    `WorkoutModel`). Other models stay `internal` to `FitnessStorage`
///    by design (YAGNI for T4 — they are not on the SPI surface).
/// 3. read and write `@Model` properties from another module (proves
///    cross-module `public var` synthesis works inside the `@Model` macro
///    in combination with `@_spi`).
///
/// These are intentionally minimal — pilot views and their tests land in
/// T5 / T6 / T7. This file only protects the package skeleton.
@MainActor
@Suite("FitnessPersistenceUI package setup")
struct PackageSetupTests {

    @Test("Module ships a version marker (skeleton sanity)")
    func skeletonExportsModuleVersion() {
        #expect(!FitnessPersistenceUI.moduleVersion.isEmpty)
    }

    @Test("In-memory ModelContainer with the SPI-visible schema can be built")
    func canBuildInMemoryContainer() throws {
        let container = try makeContainer()
        #expect(container.schema.entities.count >= 2)
    }

    @Test("Cross-module @Model property access compiles and round-trips")
    func canReadAndWriteExerciseModelAcrossModules() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let workoutId = UUID()
        let workout = WorkoutModel(
            id: workoutId,
            name: "Test workout",
            selectedCategories: [MuscleCategoryGroup.chest.rawValue],
            createdDate: .now,
            lastModified: .now
        )
        context.insert(workout)
        let exercise = ExerciseModel(
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
        context.insert(exercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ExerciseModel>()).first
        let unwrapped = try #require(fetched)
        #expect(unwrapped.name == "Bench")
        #expect(unwrapped.workoutId == workoutId)
        #expect(unwrapped.workout?.id == workoutId)
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // Skeleton-only container — limited to the two model types currently
        // on the @_spi(PersistenceUI) surface. Other @Model types stay
        // internal to FitnessStorage and are exercised by FitnessStorage's
        // own test target. T5+ will keep this list in lockstep with the
        // SPI surface as new pilot views land.
        return try ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            configurations: config
        )
    }
}
