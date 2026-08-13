import FitnessCore
import FitnessTestSupport
import FitnessUI
import SnapshotTesting
import SwiftUI
import Testing
@testable import FitnessAnalytics
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
@Suite("Bilateral analytics entry — Snapshots", .tags(.snapshot), .serialized)
@MainActor
struct AnalyticsEntryFormSnapshotTests {
    @Test(
        "Manual bilateral input aligns at supported widths",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func inputLayout(width: CGFloat) {
        let exercise = FitnessTestSupport.makeExercise(
            name: "Torso Rotation",
            weight: 20,
            reps: 12,
            sets: 3,
            category: .abs,
            executionMode: .bilateral
        )
        let size = CGSize(width: width, height: 620)
        let view = AddAnalyticsEntryView(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            exercise: exercise,
            isPresented: .constant(true),
            onSave: { _ in },
            onCancel: {}
        )
        .appColorTheme(.green)
        .frame(width: size.width, height: size.height)
        .background(AppStyle.Color.backgroundColor)

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black
        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }
        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .wait(
                for: 0.25,
                on: .image(
                    precision: 0.99,
                    perceptualPrecision: 0.98,
                    size: size
                )
            ),
            named: "bilateral-input-\(Int(width))"
        )
    }
}
#endif
