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

/// Hosts a view and forces it through layout so `onAppear` runs, without
/// comparing an image.
///
/// Used where the contract under test is what the card *reads*, not how it
/// looks. Rendering is the trigger for those reads, which is why this cannot
/// simply be dropped — but a stored baseline would add churn on every
/// intentional redesign for no extra risk reduction.
@MainActor
private func renderForSideEffects<V: View>(_ view: V, size: CGSize) {
    let controller = UIHostingController(rootView: view)
    // A window, not just `loadViewIfNeeded()`: `onAppear` fires when the view
    // actually appears in a hierarchy, and the reads under test happen there.
    // Hosting without a window silently ran no reads at all and made the
    // assertions below vacuous.
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    window.rootViewController = controller
    window.isHidden = false
    window.layoutIfNeeded()
}

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
        // `precision` is the share of pixels allowed to differ, and 0.99 was
        // loose enough to pass a baseline that no longer matched: a 1pt
        // geometry shift on a 393-wide card moves well under 1% of the pixels.
        // These are card primitives whose geometry *is* the contract, so the
        // pixel budget is tightened to catch that. `perceptualPrecision` stays
        // at 0.98 — it absorbs per-pixel antialiasing noise, which is the
        // variation that should be tolerated.
        as: .image(precision: 0.999, perceptualPrecision: 0.98, size: size),
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

}

// MARK: - InactiveCardModelView Snapshots

@Suite("InactiveCardModelView — Read path", .tags(.integration))
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


    /// The collapsed completed card must stay on the cheap read path. The
    /// visual side of this used to be a stored snapshot; it was removed because
    /// the card is a feature composition whose geometry changes on purpose,
    /// so every redesign cost a baseline re-record while catching nothing the
    /// assertions below do not.
    @Test func collapsedCardReadsOnlyTheBoundedRecentPath() throws {
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

        renderForSideEffects(view, size: CGSize(width: 393, height: 120))
        // The collapsed card shows the session-improvement row, so it does read
        // — but only through the bounded two-day path. The expensive reads stay
        // untouched until the card is expanded, which is the contract this
        // assertion protects. Before `loadRecentEntries` had its own tracking,
        // the mock inherited it from `loadHistory` and the two were
        // indistinguishable here.
        #expect(storage.recentLoadCallCount == 1)
        #expect(storage.recentLoadDayLimits == [2])
        #expect(storage.availabilityCallCount == 0)
        #expect(storage.latestLoadCallCount == 0)
        #expect(storage.loadCallCount == 0)
    }
}
