import Foundation
import Observation
import SwiftData
import SwiftUI
import Testing
@testable import FitnessExercise
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) import FitnessStorage

#if canImport(UIKit)
import UIKit

@MainActor
@Observable
private final class WorkoutSelection {
    var workoutId: UUID

    init(workoutId: UUID) {
        self.workoutId = workoutId
    }
}

@MainActor
@Observable
private final class QueryResultProbe {
    var exerciseIds: [UUID] = []
    var learnedExerciseIds: [UUID] = []

    func update(exerciseIds: [UUID], learnedExerciseIds: [UUID]) {
        self.exerciseIds = exerciseIds
        self.learnedExerciseIds = learnedExerciseIds
    }
}

private struct QueryResultProbeView: View {
    let exerciseIds: [UUID]
    let learnedExerciseIds: [UUID]
    let probe: QueryResultProbe

    var body: some View {
        Color.clear
            .onAppear(perform: updateProbe)
            .onChange(of: exerciseIds) { _, _ in updateProbe() }
            .onChange(of: learnedExerciseIds) { _, _ in updateProbe() }
    }

    private func updateProbe() {
        probe.update(
            exerciseIds: exerciseIds,
            learnedExerciseIds: learnedExerciseIds
        )
    }
}

private struct WorkoutQueryHarness: View {
    let selection: WorkoutSelection
    let probe: QueryResultProbe

    var body: some View {
        let workoutId = selection.workoutId
        WorkoutScopedExerciseQueryView(workoutId: workoutId) {
            exerciseModels,
            learnedExerciseIds in
            let sorted = ExerciseListOrderResolver.sorted(
                exerciseModels,
                learnedExerciseIds: learnedExerciseIds
            )
            QueryResultProbeView(
                exerciseIds: sorted.map(\.id),
                learnedExerciseIds: learnedExerciseIds,
                probe: probe
            )
        }
        .id(workoutId)
    }
}

@Suite("WorkoutScopedExerciseQueryView", .tags(.integration))
@MainActor
struct WorkoutScopedExerciseQueryViewTests {
    @Test("Switching workouts rebinds exercises and learned order without leakage")
    func workoutSwitchRebindsBothQueries() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstWorkout = makeWorkout(name: "First")
        let secondWorkout = makeWorkout(name: "Second")
        context.insert(firstWorkout)
        context.insert(secondWorkout)

        let firstA = insertExercise(
            name: "First A",
            sortOrder: 0,
            workout: firstWorkout,
            context: context
        )
        let firstB = insertExercise(
            name: "First B",
            sortOrder: 1,
            workout: firstWorkout,
            context: context
        )
        let secondA = insertExercise(
            name: "Second A",
            sortOrder: 0,
            workout: secondWorkout,
            context: context
        )
        let secondB = insertExercise(
            name: "Second B",
            sortOrder: 1,
            workout: secondWorkout,
            context: context
        )
        let firstOrder = WorkoutExerciseOrderModel(
            workoutId: firstWorkout.id,
            learnedExerciseIds: [firstB.id, firstA.id]
        )
        context.insert(firstOrder)
        context.insert(WorkoutExerciseOrderModel(
            workoutId: secondWorkout.id,
            learnedExerciseIds: [secondB.id, secondA.id]
        ))
        try context.save()

        let selection = WorkoutSelection(workoutId: firstWorkout.id)
        let probe = QueryResultProbe()
        let host = UIHostingController(
            rootView: WorkoutQueryHarness(selection: selection, probe: probe)
                .modelContainer(container)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()
        host.view.layoutIfNeeded()

        try await waitUntil {
            probe.exerciseIds == [firstB.id, firstA.id]
        }
        #expect(probe.learnedExerciseIds == [firstB.id, firstA.id])

        firstOrder.learnedExerciseIds = [firstA.id, firstB.id]
        try context.save()

        try await waitUntil {
            probe.exerciseIds == [firstA.id, firstB.id]
        }
        #expect(probe.learnedExerciseIds == [firstA.id, firstB.id])

        selection.workoutId = secondWorkout.id
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        try await waitUntil {
            probe.exerciseIds == [secondB.id, secondA.id]
        }
        #expect(probe.learnedExerciseIds == [secondB.id, secondA.id])
        #expect(!probe.exerciseIds.contains(firstA.id))
        #expect(!probe.exerciseIds.contains(firstB.id))
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            WorkoutExerciseOrderModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeWorkout(name: String) -> WorkoutModel {
        WorkoutModel(
            id: UUID(),
            name: name,
            selectedCategories: [MuscleCategoryGroup.arms.rawValue],
            createdDate: .now,
            lastModified: .now
        )
    }

    private func insertExercise(
        name: String,
        sortOrder: Int,
        workout: WorkoutModel,
        context: ModelContext
    ) -> ExerciseModel {
        let exercise = ExerciseModel(
            id: UUID(),
            workoutId: workout.id,
            name: name,
            weight: 20,
            reps: 10,
            sets: 3,
            iconName: MuscleCategoryGroup.arms.defaultIconName,
            category: MuscleCategoryGroup.arms.rawValue,
            sortOrder: sortOrder,
            isActive: true,
            workout: workout
        )
        context.insert(exercise)
        return exercise
    }
}
#endif
