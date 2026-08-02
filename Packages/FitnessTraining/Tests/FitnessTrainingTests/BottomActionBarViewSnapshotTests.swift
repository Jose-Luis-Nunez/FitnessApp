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
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func setControls(width: CGFloat) {
        let exercise = makeExercise(sets: 3)
        let viewModel = BottomActionBarViewModel(
            isSetInProgress: true,
            currentSet: 1,
            currentExercise: exercise,
            hasActiveExercise: true,
            exercises: [exercise],
            isLastSetCompleted: false,
            quickDoneAllCompleted: false,
            didEditCompleteSet: false,
            didJustEditSet: false
        )
        let size = CGSize(width: width, height: 72)
        let view = FloatingActionButtonsView(
            viewModel: viewModel,
            onStart: {},
            onCompleteSet: {},
            onQuickDone: {},
            onCategoryReset: {},
            onEditLess: {},
            onEditMore: {},
            onFinish: {},
            onAddExercise: {},
            onResetAllExercises: {},
            barHeight: 0,
            backgroundColor: AppStyle.Color.backgroundColor
        )
        .frame(width: size.width, height: size.height)
        .background(AppStyle.Color.backgroundColor)

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size),
            named: "set-controls-\(Int(width))",
            record: .never
        )
    }

    @Test("Timer uses the active-set card surface")
    func timerSurface() {
        let size = CGSize(width: 320, height: 160)
        let view = CompactTimerComponent(
            viewModel: ActiveSetViewModel(),
            onCancel: {}
        )
        .frame(width: size.width, height: size.height)
        .background(AppStyle.Color.backgroundColor)

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size),
            named: "timer-surface",
            record: .never
        )
    }
}
#endif
