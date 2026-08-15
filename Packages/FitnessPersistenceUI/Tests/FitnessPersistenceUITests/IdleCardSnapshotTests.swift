import Testing
import SwiftUI
import SwiftData
import SnapshotTesting
import FitnessCore
import FitnessUI
import FitnessAnalytics
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
        .appColorTheme(.green)
        .environment(\.locale, Locale(identifier: "en_US"))
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

private func snapshotImageProvider(artworkName: String) throws -> (String) -> Image {
    let images = [
        artworkName: try appAssetImage(named: artworkName),
        "seat_arrow_medium": try appAssetImage(named: "seat_arrow_medium"),
        "analytics_icon_2": try appAssetImage(named: "analytics_icon_2"),
        "tip_coaching_2": try appAssetImage(named: "tip_coaching_2"),
    ]

    return { name in
        guard let image = images[name] else {
            preconditionFailure("Missing snapshot image fixture: \(name)")
        }
        return image
    }
}

// MARK: - IdleActiveCardModelView Snapshots

@Suite("IdleActiveCardModelView — Snapshots", .tags(.snapshot))
@MainActor
struct IdleCardSnapshotTests {

    @Test func latestLoadFailureKeepsLastRunAvailableForRetry() {
        var state = LastRunCardPresentationState()
        state.updateAvailability(true)

        let didExpand = state.apply(.failed)

        #expect(!didExpand)
        #expect(state.hasHistory)
        #expect(state.setProgress.isEmpty)
        #expect(state.date == nil)
    }

    @Test func availabilityFailurePreservesExistingLastRunAffordance() {
        var state = LastRunCardPresentationState()
        state.applyAvailability(.loaded(true))

        state.applyAvailability(.failed)

        #expect(state.hasHistory)
    }

    @Test func successfulEmptyLatestLoadRemovesLastRunAffordance() {
        var state = LastRunCardPresentationState()
        state.updateAvailability(true)

        let didExpand = state.apply(.loaded(nil))

        #expect(!didExpand)
        #expect(!state.hasHistory)
        #expect(state.setProgress.isEmpty)
        #expect(state.date == nil)
    }

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
            isInProgress: false,
            imageProvider: try snapshotImageProvider(
                artworkName: model.categoryGroup.defaultIconName
            )
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "collapsed", size: CGSize(width: 393, height: 160))
    }

    /// A four-part seat string must render only the first two positions on the
    /// idle card (positions 3 & 4 are saved but hidden). Locks in the
    /// `prefix(2)` truncation in `IdleActiveCardModelView`.
    @Test func collapsedWithLongSeat() throws {
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
            seatSetting: "A / B / C / D",
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
            isInProgress: false,
            imageProvider: try snapshotImageProvider(
                artworkName: model.categoryGroup.defaultIconName
            )
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "with-long-seat", size: CGSize(width: 393, height: 160))
    }

    @Test func collapsedWithHistory() throws {
        let (model, container) = try makeIdleCardContainer()
        let storage = MockAnalyticsStorage()
        storage.save([
            AnalyticsEntry(
                exerciseId: model.id,
                date: Date(timeIntervalSince1970: 1_735_689_600),
                setProgress: [
                    SetProgress(status: .completedDone, currentReps: 10, weight: 20),
                    SetProgress(status: .completedDone, currentReps: 10, weight: 20),
                    SetProgress(status: .completedDone, currentReps: 10, weight: 20),
                ]
            ),
        ], for: model.id)
        let analyticsVM = AnalyticsViewModel(
            storageService: storage,
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )
        storage.resetLoadTracking()
        let view = IdleActiveCardModelView(
            model: model,
            analyticsViewModel: analyticsVM,
            onEdit: { _, _ in },
            isEditable: false,
            onStart: { _ in },
            imageProvider: try snapshotImageProvider(
                artworkName: model.categoryGroup.defaultIconName
            )
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "with-history", size: CGSize(width: 393, height: 220))
        #expect(storage.availabilityCallCount == 1)
        #expect(storage.latestLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
    }

    @Test func collapsedBodyweightWithHistory() throws {
        let (model, container) = try makeIdleCardContainer()
        model.weight = 0
        model.reps = 15
        try container.mainContext.save()

        let storage = MockAnalyticsStorage()
        storage.save([
            AnalyticsEntry(
                exerciseId: model.id,
                date: Date(timeIntervalSince1970: 1_735_689_600),
                setProgress: [
                    SetProgress(status: .completedDone, currentReps: 15, weight: 0),
                    SetProgress(status: .completedDone, currentReps: 15, weight: 0),
                    SetProgress(status: .completedDone, currentReps: 15, weight: 0),
                ]
            ),
        ], for: model.id)
        let analyticsVM = AnalyticsViewModel(
            storageService: storage,
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )
        storage.resetLoadTracking()

        let view = IdleActiveCardModelView(
            model: model,
            analyticsViewModel: analyticsVM,
            onEdit: { _, _ in },
            isEditable: false,
            onStart: { _ in },
            imageProvider: try snapshotImageProvider(
                artworkName: model.categoryGroup.defaultIconName
            )
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "bodyweight-with-history", size: CGSize(width: 393, height: 220))
        #expect(storage.availabilityCallCount == 1)
        #expect(storage.latestLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
    }

    @Test func expandedLastRunWithOverflow() throws {
        let (model, container) = try makeIdleCardContainer()
        let storage = MockAnalyticsStorage()
        storage.save([
            AnalyticsEntry(
                exerciseId: model.id,
                date: Date(timeIntervalSince1970: 1_735_689_600),
                setProgress: (0..<5).map { index in
                    SetProgress(
                        status: .completedDone,
                        currentReps: 10 + index,
                        weight: 20 + Double(index) * 2.5
                    )
                }
            ),
        ], for: model.id)
        let analyticsVM = AnalyticsViewModel(
            storageService: storage,
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )
        storage.resetLoadTracking()
        let view = IdleActiveCardModelView(
            model: model,
            analyticsViewModel: analyticsVM,
            onEdit: { _, _ in },
            isEditable: false,
            onStart: { _ in },
            initiallyExpanded: false,
            initiallyLastRunExpanded: true,
            imageProvider: try snapshotImageProvider(
                artworkName: model.categoryGroup.defaultIconName
            )
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "expanded-last-run-overflow", size: CGSize(width: 393, height: 360))
        #expect(storage.availabilityCallCount == 1)
        #expect(storage.latestLoadCallCount == 1)
        #expect(storage.loadCallCount == 0)
    }

    @Test func selectionMode() throws {
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
            isSelectionMode: true,
            isSelected: true,
            imageProvider: try snapshotImageProvider(
                artworkName: model.categoryGroup.defaultIconName
            )
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "selection-mode", size: CGSize(width: 393, height: 160))
    }
}

// MARK: - InactiveCardModelView Snapshots

@Suite("InactiveCardModelView — Snapshots", .tags(.snapshot))
@MainActor
struct InactiveCardSnapshotTests {

    @Test func failedInitialLatestReadDoesNotExpandEmptyDetails() {
        var state = LatestSetProgressCardState()

        let shouldExpand = state.apply(.failed)

        #expect(!shouldExpand)
        #expect(state.setProgress.isEmpty)
    }

    @Test func failedRefreshPreservesPreviouslyLoadedSetDetails() {
        let existing = SetProgress(
            status: .completedDone,
            currentReps: 10,
            weight: 20
        )
        var state = LatestSetProgressCardState()
        let entry = AnalyticsEntry(
            exerciseId: UUID(),
            date: Date(timeIntervalSince1970: 1_735_689_600),
            setProgress: [existing]
        )
        let shouldExpand = state.apply(.loaded(entry))

        let shouldRemainExpanded = state.apply(.failed)

        #expect(shouldExpand)
        #expect(shouldRemainExpanded)
        #expect(state.setProgress == [existing])
    }

    @Test func inactiveCollapsed() throws {
        let (model, container) = try makeIdleCardContainer()
        model.isCompleted = true
        try container.mainContext.save()

        let storage = MockAnalyticsStorage()
        let analyticsVM = AnalyticsViewModel(
            storageService: storage,
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )

        let view = InactiveCardModelView(
            model: model,
            onEdit: { _, _ in },
            isEditable: false,
            analyticsViewModel: analyticsVM,
            onReset: nil,
            isResetEnabled: false,
            imageProvider: try snapshotImageProvider(
                artworkName: model.displayIconName
            )
        )
        .modelContainer(container)

        assertSnapshot(of: view, named: "collapsed", size: CGSize(width: 393, height: 120))
        #expect(storage.availabilityCallCount == 0)
        #expect(storage.latestLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
    }
}
