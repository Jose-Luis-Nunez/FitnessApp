import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@testable import FitnessStorageTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

/// Regression coverage for the self-healing path in `WorkoutStorageService.init`
/// that repairs the corruption shape produced by the pre-fix legacy-import
/// startup race: an empty service-seeded auto-"Workout 1" sitting on top of
/// successfully-imported pre-T3 workouts. The race itself (eager `@State`
/// resolved the service before the JSON → SwiftData migration landed) is now
/// prevented by `ModelContainerBootstrap.makeProductionContainer()`; this heal
/// pass is the second line of defence that repairs installs that already
/// shipped the broken state without requiring a fresh app reinstall.
///
/// See `WorkoutStorageService.healInheritedAutoDefaultIfNeeded` for the four
/// markers used to identify a service-seeded auto-default. These tests pin the
/// detector against:
///   - the canonical reproduction (inherited auto-default next to imported
///     real workouts),
///   - the fresh-install case (must NOT delete the seed — there are no real
///     workouts to fall back on),
///   - the user-created "Workout 1" case (must NOT delete it — `isDefault`
///     and/or createdDate ordering disqualify it).
@Suite("WorkoutStorageService heals inherited auto-defaults", .tags(.integration))
@MainActor
struct WorkoutStorageServiceHealingTests {

    private func makeSUTContainer() -> (ModelContainer, UserDefaults) {
        (TestHelpers.makeInMemoryContainer(), TestHelpers.makeIsolatedDefaults())
    }

    /// Plants the canonical inherited-auto-default shape: a service-seeded
    /// auto-default "Workout 1" (created `now`, default, empty) sitting next
    /// to a real imported workout with exercises and an older `createdDate`.
    private func plantInheritedAutoDefaultShape(in container: ModelContainer) -> (autoId: UUID, realId: UUID) {
        let ctx = ModelContext(container)
        let realWorkoutId = UUID()
        let realWorkout = WorkoutModel(
            id: realWorkoutId,
            name: "Holmes Place",
            selectedCategories: ["arms", "chest"],
            createdDate: Date(timeIntervalSinceNow: -86_400 * 365),
            lastModified: Date(timeIntervalSinceNow: -86_400 * 30),
            isDefault: false
        )
        let exercise = ExerciseModel(
            id: UUID(), name: "Stange ziehen", weight: 30, reps: 10, sets: 3,
            iconName: "arm", category: "arms", sortOrder: 0, workout: realWorkout
        )
        ctx.insert(realWorkout)
        ctx.insert(exercise)

        let autoId = UUID()
        let autoSeed = WorkoutModel(
            id: autoId,
            name: "Workout 1",
            selectedCategories: [],
            createdDate: Date(),
            lastModified: Date(),
            isDefault: true
        )
        ctx.insert(autoSeed)
        try! ctx.save()

        return (autoId, realWorkoutId)
    }

    @Test("Inherited auto-default next to imported workout: auto-default removed, current/default repointed to real workout")
    func healsInheritedAutoDefaultShape() {
        let (container, defaults) = makeSUTContainer()
        let (autoId, realId) = plantInheritedAutoDefaultShape(in: container)

        defaults.set(autoId.uuidString, forKey: "current_workout_id")
        defaults.set(autoId.uuidString, forKey: "default_workout_id")

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring(), analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())

        #expect(sut.workouts.count == 1, "Auto-default must be removed, leaving only the real workout.")
        #expect(sut.workouts.first?.id == realId)
        #expect(sut.workouts.first?.name == "Holmes Place")
        #expect(sut.currentWorkout?.id == realId, "current_workout_id must be repointed away from the deleted auto-default.")
        #expect(sut.defaultWorkout?.id == realId, "default_workout_id must be repointed too.")
        #expect(defaults.string(forKey: "current_workout_id") == realId.uuidString)
        #expect(defaults.string(forKey: "default_workout_id") == realId.uuidString)
    }

    @Test("Fresh install: auto-default seed survives because there is no real workout to fall back on")
    func freshInstallLeavesSeedAlone() {
        let (container, defaults) = makeSUTContainer()
        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring(), analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())

        #expect(sut.workouts.count == 1)
        #expect(sut.workouts.first?.name == "Workout 1")
        #expect(sut.defaultWorkout?.id == sut.workouts.first?.id)
    }

    @Test("User-created 'Workout 1' is NOT deleted (newer than the others — would be deleted by older versions of the heuristic)")
    func userCreatedWorkout1Survives() {
        let (container, defaults) = makeSUTContainer()
        let ctx = ModelContext(container)

        let oldUserWorkout = WorkoutModel(
            id: UUID(), name: "Legs", selectedCategories: ["legs"],
            createdDate: Date(timeIntervalSinceNow: -86_400 * 7),
            lastModified: Date(timeIntervalSinceNow: -86_400 * 7),
            isDefault: true
        )
        ctx.insert(oldUserWorkout)

        let userMadeWorkout1 = WorkoutModel(
            id: UUID(), name: "Workout 1", selectedCategories: [],
            createdDate: Date(),
            lastModified: Date(),
            isDefault: false
        )
        ctx.insert(userMadeWorkout1)
        try! ctx.save()

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring(), analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())

        #expect(sut.workouts.count == 2, "User-created 'Workout 1' must survive: it is not isDefault.")
        #expect(sut.workouts.contains { $0.name == "Workout 1" })
        #expect(sut.workouts.contains { $0.name == "Legs" })
    }

    @Test("Auto-default survives if it has exercises (i.e. user added to it before the next launch)")
    func autoDefaultWithExercisesSurvives() {
        let (container, defaults) = makeSUTContainer()
        let ctx = ModelContext(container)

        let realWorkout = WorkoutModel(
            id: UUID(), name: "Holmes Place", selectedCategories: ["chest"],
            createdDate: Date(timeIntervalSinceNow: -86_400 * 365),
            lastModified: Date(timeIntervalSinceNow: -86_400),
            isDefault: false
        )
        ctx.insert(realWorkout)

        let formerlyAutoNowPopulated = WorkoutModel(
            id: UUID(), name: "Workout 1", selectedCategories: [],
            createdDate: Date(),
            lastModified: Date(),
            isDefault: true
        )
        let exercise = ExerciseModel(
            id: UUID(), name: "Squat", weight: 60, reps: 5, sets: 5,
            iconName: "leg", category: "legs", sortOrder: 0, workout: formerlyAutoNowPopulated
        )
        ctx.insert(formerlyAutoNowPopulated)
        ctx.insert(exercise)
        try! ctx.save()

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring(), analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())

        #expect(sut.workouts.count == 2, "Workout 1 was auto-seeded but the user added exercises — must NOT be deleted.")
    }

    @Test("Empty 'Workout 1' that is the OLDEST workout is left alone (likely user-created earlier)")
    func oldestEmptyWorkout1Survives() {
        let (container, defaults) = makeSUTContainer()
        let ctx = ModelContext(container)

        let oldEmptyWorkout1 = WorkoutModel(
            id: UUID(), name: "Workout 1", selectedCategories: [],
            createdDate: Date(timeIntervalSinceNow: -86_400 * 30),
            lastModified: Date(timeIntervalSinceNow: -86_400 * 30),
            isDefault: true
        )
        ctx.insert(oldEmptyWorkout1)

        let newerWorkout = WorkoutModel(
            id: UUID(), name: "Beinpressen", selectedCategories: ["legs"],
            createdDate: Date(),
            lastModified: Date(),
            isDefault: false
        )
        ctx.insert(newerWorkout)
        try! ctx.save()

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: TestHelpers.makeNoOpExerciseStoring(), analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())

        #expect(sut.workouts.count == 2, "Old empty 'Workout 1' is older than the rest — likely a deliberate user-created shell, must survive.")
    }
}
