import FitnessCore
import FitnessTestSupport
import FitnessUI
import SnapshotTesting
import SwiftUI
import Testing
@testable import FitnessTraining

#if canImport(UIKit)
import UIKit

@Suite("Bottom action bar — Snapshots", .tags(.snapshot), .serialized)
@MainActor
struct BottomActionBarViewSnapshotTests {
    @Test(
        "Set controls are separate pills at compact, regular, and large widths",
        arguments: [CGFloat(320), CGFloat(430)]
    )
    func setControls(width: CGFloat) {
        let exercise = makeExercise(sets: 3)
        let viewModel = BottomActionBarViewModel(
            isSetInProgress: true,
            currentSet: 1,
            currentExercise: exercise,
            hasActiveExercise: true,
            isLastSetCompleted: false,
            didEditCompleteSet: false,
            didJustEditSet: false
        )
        let size = CGSize(width: width, height: 72)
        let view = FloatingActionButtonsView(
            viewModel: viewModel,
            onStart: {},
            onCompleteSet: {},
            onQuickDone: {},
            onEditLess: {},
            onEditMore: {},
            onFinish: {}
        )
        .appColorTheme(.green)
        .environment(\.locale, Locale(identifier: "en_US"))
        .frame(width: size.width, height: size.height)
        .background(AppStyle.Color.backgroundColor)

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .image(precision: 0.999, perceptualPrecision: 0.98, size: size),
            named: "set-controls-\(Int(width))",
            record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
                ? .all
                : .never
        )
    }

    /// The feedback entry point had no visual coverage at all, which is why a
    /// 3:2 asset rendering a third shorter than its siblings went unnoticed and
    /// why nothing caught the earlier `.fill` crop. All three states in one
    /// image, so a size or clipping difference between them is visible at a
    /// glance rather than inferred from canvas measurements.
    @Test(
        "Feedback entry point renders every state at one apparent size",
        arguments: [FeedbackEntryIconState.entry, .draft, .done]
    )
    func feedbackIcon(state: FeedbackEntryIconState) throws {
        // Every state, not just the one under test, so the provider's
        // state -> image mapping is exercised rather than bypassed by returning
        // a single image regardless of input. `appAssetImage` throws on a
        // missing file, so a renamed asset fails the suite instead of rendering
        // a stable empty circle.
        let artwork = try [FeedbackEntryIconState.entry, .draft, .done]
            .reduce(into: [String: Image]()) { images, iconState in
                images[iconState.assetName] = try appAssetImage(named: iconState.assetName)
            }
        let exercise = makeExercise(sets: 3)
        // `showFeedbackButton` mirrors `showFinishButton`, so the slot only
        // exists once the last set is complete — which is also the only moment
        // a user sees this icon.
        let viewModel = BottomActionBarViewModel(
            isSetInProgress: false,
            currentSet: 3,
            currentExercise: exercise,
            hasActiveExercise: true,
            isLastSetCompleted: true,
            didEditCompleteSet: false,
            didJustEditSet: false
        )
        let size = CGSize(width: 120, height: 72)
        let view = BottomActionBarView(
            viewModel: viewModel,
            onStart: {},
            onCompleteSet: {},
            onQuickDone: {},
            onEditLess: {},
            onEditMore: {},
            onFinish: {},
            onOpenFeedback: {},
            feedbackIconState: state,
            // The artwork lives in the app target's catalog, so it has to be
            // loaded from disk here — `Image(_:)` would silently resolve to
            // nothing and the test would pass against an empty circle.
            feedbackImageProvider: { artwork[$0.assetName]! }
        )
        .appColorTheme(.green)
        .environment(\.locale, Locale(identifier: "en_US"))
        .frame(width: 430, height: size.height)
        .background(AppStyle.Color.backgroundColor)

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: CGSize(width: 430, height: size.height))
        controller.view.backgroundColor = .black

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .image(precision: 0.999, perceptualPrecision: 0.98, size: CGSize(width: 430, height: size.height)),
            named: "feedback-\(state)",
            record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
                ? .all
                : .never
        )
    }

    @Test("Timer uses the active-set card surface")
    func timerSurface() {
        let size = CGSize(width: 320, height: 160)
        let view = CompactTimerComponent(
            viewModel: ActiveSetViewModel(),
            onCancel: {}
        )
        .appColorTheme(.green)
        .environment(\.locale, Locale(identifier: "en_US"))
        .frame(width: size.width, height: size.height)
        .background(AppStyle.Color.backgroundColor)

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .image(precision: 0.999, perceptualPrecision: 0.98, size: size),
            named: "timer-surface",
            record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
                ? .all
                : .never
        )
    }
}
#endif
