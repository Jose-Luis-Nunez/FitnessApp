import Testing
import SwiftUI
import SwiftData
import SnapshotTesting
import FitnessCore
import FitnessUI
import FitnessAnalytics
import FitnessTraining
import FitnessTestSupport
@_spi(PersistenceUI) import FitnessStorage
@_spi(PersistenceUI) @testable import FitnessPersistenceUI

// MARK: - Helpers

@MainActor
private func assertSnapshot<V: View>(
    of view: V,
    named name: String,
    size: CGSize = CGSize(width: 393, height: 200),
    record: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation,
    file: StaticString = #filePath,
    function: StaticString = #function
) {
    let hosted = view
        .frame(width: size.width, height: size.height)
        .background(AppStyle.Color.backgroundColor)

    let controller = UIHostingController(rootView: hosted)
    controller.view.frame = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .black

    let shouldRecord = record || ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"

    SnapshotTesting.assertSnapshot(
        of: controller,
        as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size),
        named: name,
        record: shouldRecord,
        file: file,
        testName: "\(function)",
        line: UInt(sourceLocation.line)
    )
}

@MainActor
private func makeIdleCardContainer() throws -> (ExerciseModel, ModelContainer) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: WorkoutModel.self, ExerciseModel.self,
        configurations: config
    )
    let ctx = container.mainContext

    let workoutId = UUID()
    let workout = WorkoutModel(
        id: workoutId,
        name: "Push",
        selectedCategories: [MuscleCategoryGroup.arms.rawValue],
        createdDate: .now,
        lastModified: .now
    )
    ctx.insert(workout)

    let model = ExerciseModel(
        id: UUID(),
        workoutId: workoutId,
        name: "Curl",
        weight: 20,
        reps: 10,
        sets: 3,
        noSeats: true,
        iconName: MuscleCategoryGroup.arms.defaultIconName,
        category: MuscleCategoryGroup.arms.rawValue,
        workout: workout
    )
    ctx.insert(model)
    try ctx.save()

    return (model, container)
}

// MARK: - IdleActiveCardModelView Snapshots

@Suite("IdleActiveCardModelView — Snapshots", .tags(.snapshot))
@MainActor
struct IdleCardSnapshotTests {

    @Test func collapsed() throws {
        let (model, container) = try makeIdleCardContainer()
        let analyticsVM = AnalyticsViewModel(
            storageService: StubAnalyticsStorage(),
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )

        let view = IdleActiveCardModelView(
            model: model,
            analyticsViewModel: analyticsVM,
            onEdit: { _, _ in },
            isEditable: false,
            onStart: { _ in },
            isInProgress: false
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "collapsed", size: CGSize(width: 393, height: 160))
    }

    @Test func collapsedWithSeat() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutModel.self, ExerciseModel.self,
            configurations: config
        )
        let ctx = container.mainContext

        let workoutId = UUID()
        let workout = WorkoutModel(
            id: workoutId,
            name: "Push",
            selectedCategories: [MuscleCategoryGroup.chest.rawValue],
            createdDate: .now,
            lastModified: .now
        )
        ctx.insert(workout)

        let model = ExerciseModel(
            id: UUID(),
            workoutId: workoutId,
            name: "Butterfly",
            weight: 35,
            reps: 12,
            sets: 4,
            seatSetting: "3",
            noSeats: false,
            iconName: MuscleCategoryGroup.chest.defaultIconName,
            category: MuscleCategoryGroup.chest.rawValue,
            workout: workout
        )
        ctx.insert(model)
        try ctx.save()

        let analyticsVM = AnalyticsViewModel(
            storageService: StubAnalyticsStorage(),
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )

        let view = IdleActiveCardModelView(
            model: model,
            analyticsViewModel: analyticsVM,
            onEdit: { _, _ in },
            isEditable: false,
            onStart: { _ in },
            isInProgress: false
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "with-seat", size: CGSize(width: 393, height: 160))
    }
}

// MARK: - InactiveCardModelView Snapshots

@Suite("InactiveCardModelView — Snapshots", .tags(.snapshot))
@MainActor
struct InactiveCardSnapshotTests {

    @Test func inactiveCollapsed() throws {
        let (model, container) = try makeIdleCardContainer()
        model.isCompleted = true
        try container.mainContext.save()

        let analyticsVM = AnalyticsViewModel(
            storageService: StubAnalyticsStorage(),
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )

        let view = InactiveCardModelView(
            model: model,
            onEdit: { _, _ in },
            isEditable: false,
            analyticsViewModel: analyticsVM,
            onReset: nil,
            isResetEnabled: false
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "collapsed", size: CGSize(width: 393, height: 120))
    }
}
