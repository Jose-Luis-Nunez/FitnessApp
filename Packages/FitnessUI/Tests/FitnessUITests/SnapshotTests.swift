import Testing
import SwiftUI
import SnapshotTesting
import FitnessCore
import FitnessTestSupport
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
    let shouldRecord = record || ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
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
        record: shouldRecord,
        file: file,
        testName: "\(function)",
        line: UInt(sourceLocation.line)
    )
}

// MARK: - Category Tile Artwork Snapshots

@Suite("CategoryTileArtworkStage — Snapshots", .tags(.snapshot))
@MainActor
struct CategoryTileArtworkStageSnapshotTests {

    @Test func topAligned() {
        let view = CategoryTileArtworkStage(alignment: .top) {
            artworkAlignmentFixture
        }
        assertSnapshot(of: view, named: "top", size: CGSize(width: 120, height: 120))
    }

    @Test func bottomAligned() {
        let view = CategoryTileArtworkStage(alignment: .bottom) {
            artworkAlignmentFixture
        }
        assertSnapshot(of: view, named: "bottom", size: CGSize(width: 120, height: 120))
    }

    private var artworkAlignmentFixture: some View {
        VStack(spacing: 0) {
            Color.orange.frame(height: 40)
            Color.cyan.frame(height: 60)
            Color.indigo.frame(height: 40)
        }
        .frame(width: ExerciseCardLayout.CategoryTile.iconArtworkSize, height: 140)
    }
}

// MARK: - CardBackground Snapshots

@Suite("CardBackground — Snapshots", .tags(.snapshot))
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

    @Test func idleStyle() {
        let view = CardBackground(style: .idle) {
            Text("Idle Card")
                .foregroundColor(AppStyle.Color.idleTitle)
                .font(AppStyle.Font.cardHeadline)
        }
        assertSnapshot(of: view, named: "idle", size: CGSize(width: 350, height: 100))
    }
}

// MARK: - Adaptive Glass Policy

@Suite("Adaptive Surfaces — Policy")
@MainActor
struct AdaptiveSurfacePolicyTests {

    @Test
    func currentPlatformPolicy() {
#if os(visionOS)
        #expect(AppGlassTreatment.currentPlatform == .legacyMaterial)
        #expect(AppDarkSurfaceTreatment.currentPlatform == .nativeGlass)
#else
        if #available(iOS 27.0, macOS 27.0, *) {
            #expect(AppGlassTreatment.currentPlatform == .clear)
            #expect(AppDarkSurfaceTreatment.currentPlatform == .flat)
        } else if #available(iOS 26.0, macOS 26.0, *) {
            #expect(AppGlassTreatment.currentPlatform == .regular)
            #expect(AppDarkSurfaceTreatment.currentPlatform == .nativeGlass)
        } else {
            #expect(AppGlassTreatment.currentPlatform == .legacyMaterial)
            #expect(AppDarkSurfaceTreatment.currentPlatform == .nativeGlass)
        }
#endif
    }

}

// MARK: - CardShell Snapshots

@Suite("CardShell — Snapshots", .tags(.snapshot))
@MainActor
struct CardShellSnapshotTests {

    @Test func idleTheme() {
        let theme = CardTheme.idle
        let view = CardShell(theme: theme, leading: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray)
                .frame(width: 64, height: 64)
        }, trailing: {
            Circle()
                .fill(AppStyle.Color.idleMetricValue)
                .frame(width: 28, height: 28)
        }, titleContent: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Exercise Name")
                    .font(theme.titleFont)
                    .foregroundColor(theme.titleColor)
                Text("20 kg")
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(theme.subtitleColor)
            }
        })
        assertSnapshot(of: view, named: "idle", size: CGSize(width: 393, height: 120))
    }

    @Test func completedThemeWithEdgeIndicator() {
        let theme = CardTheme.completed
        let view = CardShell(theme: theme, edgeIndicator: .completed, leading: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray)
                .frame(width: 50, height: 50)
        }, trailing: {
            Circle()
                .fill(AppStyle.Color.greenGlow)
                .frame(width: 36, height: 36)
        }, titleContent: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bench Press")
                    .font(theme.titleFont)
                    .foregroundColor(theme.titleColor)
                Text("Completed workout")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(theme.subtitleColor)
            }
        })
        assertSnapshot(of: view, named: "completed", size: CGSize(width: 393, height: 120))
    }

    @Test func noTrailing() {
        let theme = CardTheme.idle
        let view = CardShell(theme: theme, leading: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray)
                .frame(width: 64, height: 64)
        }, titleContent: {
            Text("No Trailing")
                .font(theme.titleFont)
                .foregroundColor(theme.titleColor)
        })
        assertSnapshot(of: view, named: "no-trailing", size: CGSize(width: 393, height: 100))
    }

    @Test func withExpandedContent() {
        let theme = CardTheme.idle
        let view = CardShell(theme: theme, leading: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray)
                .frame(width: 64, height: 64)
        }, titleContent: {
            Text("With Expanded")
                .font(theme.titleFont)
                .foregroundColor(theme.titleColor)
        }, expandedContent: {
            Text("Expanded section")
                .font(AppStyle.Font.detailBadge)
                .foregroundColor(theme.subtitleColor)
                .padding(.horizontal, 8)
                .padding(.top, 8)
        })
        assertSnapshot(of: view, named: "expanded", size: CGSize(width: 393, height: 140))
    }
}

// MARK: - MiniActionMenuView Snapshots

@Suite("MiniActionMenuView — Snapshots", .tags(.snapshot))
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

@Suite("WorkoutDropdownView — Snapshots", .tags(.snapshot))
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

        let view = WorkoutDropdownView(workoutName: "My very long workout name that gets truncated")
            .environment(overlay)
        assertSnapshot(of: view, named: "long-name", size: CGSize(width: 300, height: 60))
    }
}

// MARK: - SetTileView Snapshots

@Suite("SetTileView — Snapshots", .tags(.snapshot))
@MainActor
struct SetTileViewSnapshotTests {

    @Test func withWeight() {
        let view = SetTileView(setNumber: 1, weight: 62.5, reps: 10, hasWeight: true)
        assertSnapshot(of: view, named: "with-weight", size: CGSize(width: 100, height: 90))
    }

    @Test func withoutWeight() {
        let view = SetTileView(setNumber: 3, weight: 0, reps: 15, hasWeight: false)
        assertSnapshot(of: view, named: "bodyweight", size: CGSize(width: 100, height: 90))
    }
}

// MARK: - SetTilesRow Snapshots

@Suite("SetTilesRow — Snapshots", .tags(.snapshot))
@MainActor
struct SetTilesRowSnapshotTests {

    private func progress(_ count: Int) -> [SetProgress] {
        (0..<count).map { i in
            SetProgress(status: .completedDone, currentReps: 10 + i, weight: 60 + Double(i) * 2.5)
        }
    }

    /// Three sets — fills the row exactly, no scroll chevron, no trailing accessory.
    @Test func threeSetsNoAccessory() {
        let view = SetTilesRow(
            setProgress: progress(3),
            hasWeight: true,
            chevronColor: AppStyle.Color.idleMetricLabel.opacity(AppStyle.Opacity.separatorLine),
            onTap: {}
        )
        assertSnapshot(of: view, named: "three-sets", size: CGSize(width: 360, height: 70))
    }

    /// More than three sets — the compact scroll chevron appears at the trailing edge.
    @Test func overflowWithChevron() {
        let view = SetTilesRow(
            setProgress: progress(5),
            hasWeight: false,
            chevronColor: AppStyle.Color.idleMetricLabel.opacity(AppStyle.Opacity.separatorLine),
            onTap: {}
        )
        assertSnapshot(of: view, named: "overflow-chevron", size: CGSize(width: 360, height: 70))
    }

    /// Trailing accessory (reset button) with its width reserved so the three
    /// tiles stay exact — mirrors the completed card's reset-enabled layout.
    @Test func withResetAccessory() {
        let view = SetTilesRow(
            setProgress: progress(3),
            hasWeight: true,
            chevronColor: AppStyle.Color.idleMetricLabel.opacity(AppStyle.Opacity.separatorLine),
            reservedTrailingWidth: ExerciseCardLayout.ResetButton.size,
            onTap: {}
        ) {
            ExerciseCardResetButton {}
        }
        assertSnapshot(of: view, named: "with-reset", size: CGSize(width: 360, height: 70))
    }
}

// MARK: - ProgressBar Snapshots

@Suite("ProgressBar — Snapshots", .tags(.snapshot))
@MainActor
struct ProgressBarSnapshotTests {

    @Test func empty() {
        let view = ProgressBar(progress: 0.0, totalWidth: 200)
        assertSnapshot(of: view, named: "empty", size: CGSize(width: 220, height: 30))
    }

    @Test func partial() {
        let view = ProgressBar(progress: 0.6, totalWidth: 200)
        assertSnapshot(of: view, named: "partial", size: CGSize(width: 220, height: 30))
    }

    @Test func full() {
        let view = ProgressBar(progress: 1.0, totalWidth: 200)
        assertSnapshot(of: view, named: "full", size: CGSize(width: 220, height: 30))
    }
}

// MARK: - MetricChipView Snapshots

@Suite("MetricChipView — Snapshots", .tags(.snapshot))
@MainActor
struct MetricChipViewSnapshotTests {

    @Test func defaultSize() {
        let view = MetricChipView {
            VStack(spacing: 2) {
                Text("62.5")
                    .font(AppStyle.Font.cardValueBold)
                    .foregroundColor(AppStyle.Color.greenGlow)
                Text("kg")
                    .font(AppStyle.Font.cardSmallLabel)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        assertSnapshot(of: view, named: "default", size: CGSize(width: 120, height: 90))
    }

    @Test func customWidth() {
        let view = MetricChipView(width: 160) {
            Text("3 × 10")
                .font(AppStyle.Font.cardValueBold)
                .foregroundColor(AppStyle.Color.white)
        }
        assertSnapshot(of: view, named: "wide", size: CGSize(width: 200, height: 90))
    }
}

// MARK: - CapsuleToggleStyle Snapshots

@Suite("CapsuleToggleStyle — Snapshots", .tags(.snapshot))
@MainActor
struct CapsuleToggleStyleSnapshotTests {

    @Test func toggleOn() {
        let view = Toggle("Decimal", isOn: .constant(true))
            .toggleStyle(CapsuleToggleStyle(
                onColor: AppStyle.Color.green,
                offColor: AppStyle.Color.gray.opacity(0.4)
            ))
            .labelsHidden()
        assertSnapshot(of: view, named: "on", size: CGSize(width: 80, height: 50))
    }

    @Test func toggleOff() {
        let view = Toggle("Decimal", isOn: .constant(false))
            .toggleStyle(CapsuleToggleStyle(
                onColor: AppStyle.Color.green,
                offColor: AppStyle.Color.gray.opacity(0.4)
            ))
            .labelsHidden()
        assertSnapshot(of: view, named: "off", size: CGSize(width: 80, height: 50))
    }
}

// MARK: - IdlePlayButton Snapshots

@Suite("IdlePlayButton — Snapshots", .tags(.snapshot))
@MainActor
struct IdlePlayButtonSnapshotTests {

    @Test func idle() {
        let view = IdlePlayButton()
        assertSnapshot(of: view, named: "idle", size: CGSize(width: 100, height: 100))
    }
}

// MARK: - ExerciseCardResetButton Snapshots

@Suite("ExerciseCardResetButton — Snapshots", .tags(.snapshot))
@MainActor
struct ExerciseCardResetButtonSnapshotTests {

    @Test func idleStyledReset() {
        let view = ExerciseCardResetButton(onTap: {})
        assertSnapshot(of: view, named: "idle-styled-reset", size: CGSize(width: 100, height: 100))
    }
}

// MARK: - RefreshActionButton Snapshots

@Suite("RefreshActionButton — Snapshots", .tags(.snapshot))
@MainActor
struct RefreshActionButtonSnapshotTests {

    @Test func readyState() {
        let view = RefreshActionButton(title: "Refresh", isLoading: false, action: {})
        assertSnapshot(of: view, named: "ready", size: CGSize(width: 200, height: 60))
    }

    @Test func loadingState() {
        let view = RefreshActionButton(title: "Refresh", isLoading: true, action: {})
        assertSnapshot(of: view, named: "loading", size: CGSize(width: 200, height: 60))
    }
}

// MARK: - CardTextField Snapshots

@Suite("CardTextField — Snapshots", .tags(.snapshot))
@MainActor
struct CardTextFieldSnapshotTests {

    /// Hosts `CardTextField` with the `@FocusState` it requires.
    private struct Host: View {
        let text: String
        @FocusState private var focused: Bool

        var body: some View {
            CardTextField(
                label: "Name",
                placeholder: "Workout Name",
                text: .constant(text),
                isFocused: $focused
            )
            .padding(.horizontal, AppStyle.Padding.horizontal)
        }
    }

    @Test func cardTextFieldEmpty() {
        assertSnapshot(of: Host(text: ""), named: "card-text-empty", size: CGSize(width: 350, height: 90))
    }

    @Test func cardTextFieldFilled() {
        assertSnapshot(of: Host(text: "Leg Day"), named: "card-text-filled", size: CGSize(width: 350, height: 90))
    }
}
