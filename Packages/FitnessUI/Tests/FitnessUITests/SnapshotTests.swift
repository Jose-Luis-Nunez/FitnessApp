import Testing
import SwiftUI
import SnapshotTesting
@testable import FitnessUI

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

    SnapshotTesting.assertSnapshot(
        of: controller,
        as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size),
        named: name,
        record: record,
        file: file,
        testName: "\(function)",
        line: UInt(sourceLocation.line)
    )
}

// MARK: - CardBackground Snapshots

@Suite("CardBackground — Snapshots")
@MainActor
struct CardBackgroundSnapshotTests {

    @Test func gradientStyle() {
        let view = CardBackground(style: .gradient(AppStyle.Color.exerciseCardBackground)) {
            Text("Gradient Card")
                .foregroundColor(AppStyle.Color.white)
                .font(AppStyle.Font.tileLabel)
        }
        assertSnapshot(of: view, named: "gradient", size: CGSize(width: 350, height: 100))
    }

    @Test func glassStyle() {
        let view = CardBackground(style: .glass(AppStyle.Color.exerciseCardBackground)) {
            Text("Glass Card")
                .foregroundColor(AppStyle.Color.white)
                .font(AppStyle.Font.tileLabel)
        }
        assertSnapshot(of: view, named: "glass", size: CGSize(width: 350, height: 100))
    }

    @Test func noPadding() {
        let view = CardBackground(addPadding: false) {
            Text("No Padding")
                .foregroundColor(AppStyle.Color.white)
                .font(AppStyle.Font.tileLabel)
        }
        assertSnapshot(of: view, named: "no-padding", size: CGSize(width: 350, height: 80))
    }
}

// MARK: - MiniActionMenuView Snapshots

@Suite("MiniActionMenuView — Snapshots")
@MainActor
struct MiniActionMenuSnapshotTests {

    @Test func withTitleAndItems() {
        let view = MiniActionMenuView(
            title: "Workout Options",
            items: [
                MiniActionMenuItem(icon: "plus", title: "New Exercise", isDestructive: false, action: {}),
                MiniActionMenuItem(icon: "pencil", title: "Rename", isDestructive: false, action: {}),
                MiniActionMenuItem(icon: "trash", title: "Delete", isDestructive: true, action: {}),
            ],
            width: 260
        )
        assertSnapshot(of: view, named: "with-title", size: CGSize(width: 300, height: 300))
    }

    @Test func withoutTitle() {
        let view = MiniActionMenuView(
            title: nil,
            items: [
                MiniActionMenuItem(icon: "xmark", title: "Reset all", isDestructive: false, action: {}),
            ],
            width: 260
        )
        assertSnapshot(of: view, named: "no-title", size: CGSize(width: 300, height: 200))
    }

    @Test func destructiveConfirmation() {
        let view = MiniActionMenuView(
            title: nil,
            items: [
                MiniActionMenuItem(icon: nil, title: "Confirm deletion", isDestructive: true, action: {}),
                MiniActionMenuItem(icon: nil, title: "Cancel", isDestructive: false, action: {}),
            ],
            width: 260
        )
        assertSnapshot(of: view, named: "confirm-delete", size: CGSize(width: 300, height: 200))
    }
}

// MARK: - WorkoutDropdownView Snapshots

@Suite("WorkoutDropdownView — Snapshots")
@MainActor
struct WorkoutDropdownSnapshotTests {

    @Test func collapsed() {
        let overlay = UIOverlayState()
        overlay.showWorkoutDropdown = false

        let view = WorkoutDropdownView(workoutName: "Push Day")
            .environment(overlay)
        assertSnapshot(of: view, named: "collapsed", size: CGSize(width: 300, height: 60))
    }

    @Test func expanded() {
        let overlay = UIOverlayState()
        overlay.showWorkoutDropdown = true

        let view = WorkoutDropdownView(workoutName: "Push Day")
            .environment(overlay)
        assertSnapshot(of: view, named: "expanded", size: CGSize(width: 300, height: 60))
    }

    @Test func longWorkoutName() {
        let overlay = UIOverlayState()

        let view = WorkoutDropdownView(workoutName: "Mein sehr langer Workout Name der abgeschnitten wird")
            .environment(overlay)
        assertSnapshot(of: view, named: "long-name", size: CGSize(width: 300, height: 60))
    }
}
