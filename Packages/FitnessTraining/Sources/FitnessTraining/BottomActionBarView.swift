import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI
#if canImport(UIKit)
import UIKit
#endif

public struct BottomActionBarView: View {
    public let viewModel: BottomActionBarViewModel
    public let onStart: () -> Void
    public let onCompleteSet: () -> Void
    public let onQuickDone: () -> Void
    public let onEditLess: () -> Void
    public let onEditMore: () -> Void
    public let onFinish: () -> Void
    public let onOpenFeedback: () -> Void
    public let feedbackIconState: FeedbackEntryIconState

    public init(
        viewModel: BottomActionBarViewModel,
        onStart: @escaping () -> Void,
        onCompleteSet: @escaping () -> Void,
        onQuickDone: @escaping () -> Void,
        onEditLess: @escaping () -> Void,
        onEditMore: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onOpenFeedback: @escaping () -> Void = {},
        feedbackIconState: FeedbackEntryIconState = .entry
    ) {
        self.viewModel = viewModel
        self.onStart = onStart
        self.onCompleteSet = onCompleteSet
        self.onQuickDone = onQuickDone
        self.onEditLess = onEditLess
        self.onEditMore = onEditMore
        self.onFinish = onFinish
        self.onOpenFeedback = onOpenFeedback
        self.feedbackIconState = feedbackIconState
    }

    public var body: some View {
        if viewModel.shouldShow {
            ZStack(alignment: .bottom) {
                FloatingActionButtonsView(
                    viewModel: viewModel,
                    onStart: onStart,
                    onCompleteSet: onCompleteSet,
                    onQuickDone: onQuickDone,
                    onEditLess: onEditLess,
                    onEditMore: onEditMore,
                    onFinish: onFinish,
                    onOpenFeedback: onOpenFeedback,
                    feedbackIconState: feedbackIconState
                )
            }
            .background(Color.clear)
            .zIndex(2)
        }
    }
}

public struct FloatingActionButtonsView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    public let viewModel: BottomActionBarViewModel
    public let onStart: () -> Void
    public let onCompleteSet: () -> Void
    public let onQuickDone: () -> Void
    public let onEditLess: () -> Void
    public let onEditMore: () -> Void
    public let onFinish: () -> Void
    public let onOpenFeedback: () -> Void
    public let feedbackIconState: FeedbackEntryIconState
    private let capsuleHeight: CGFloat = 48

    private let bottomOffset: CGFloat = 16
    private let setControlSurfaceHeight: CGFloat = 44
    private let setControlSurfaceHorizontalInset: CGFloat = 4

    /// Active-set controls share the app's standard button radius so their
    /// slimmer surfaces remain rounded rectangles rather than capsules.
    private var setControlCornerRadius: CGFloat {
        AppStyle.CornerRadius.bottomBarButton
    }

    public init(
        viewModel: BottomActionBarViewModel,
        onStart: @escaping () -> Void,
        onCompleteSet: @escaping () -> Void,
        onQuickDone: @escaping () -> Void,
        onEditLess: @escaping () -> Void,
        onEditMore: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onOpenFeedback: @escaping () -> Void = {},
        feedbackIconState: FeedbackEntryIconState = .entry
    ) {
        self.viewModel = viewModel
        self.onStart = onStart
        self.onCompleteSet = onCompleteSet
        self.onQuickDone = onQuickDone
        self.onEditLess = onEditLess
        self.onEditMore = onEditMore
        self.onFinish = onFinish
        self.onOpenFeedback = onOpenFeedback
        self.feedbackIconState = feedbackIconState
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 6) {
                if viewModel.showSetControls {
                    setControlButtons
                } else {
                    primaryActionCapsule
                }

                if viewModel.showSetControls && viewModel.currentSet == 0 {
                    menuIconItem(
                        icon: "quickDoneIcon",
                        action: onQuickDone,
                        style: .quickDone
                    )
                } else if viewModel.showFeedbackButton {
                    feedbackIconButton(state: feedbackIconState, action: onOpenFeedback)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.bottom, bottomOffset)
        .frame(height: capsuleHeight + 6)
    }

    enum MenuItemStyle {
        case control, done, start, finish, allDone, quickDone, feedback
    }

    /// Active-set controls deliberately use three distinct surfaces rather
    /// than a single segmented capsule: "Done" reads as the primary action,
    /// while "Less" and "More" remain secondary adjustments.
    private var setControlButtons: some View {
        HStack(spacing: 8) {
            menuTextItem(text: AppText.actionLess, accessibilityToken: "Less", action: onEditLess, style: .control)
            menuTextItem(text: AppText.actionDone, action: onCompleteSet, style: .done)
            menuTextItem(text: AppText.actionMore, accessibilityToken: "More", action: onEditMore, style: .control)
        }
        .frame(maxWidth: .infinity, maxHeight: capsuleHeight)
    }

    /// The start and finish states retain their existing single, shared
    /// capsule. Only the active-set controls become separate buttons.
    private var primaryActionCapsule: some View {
        ZStack {
            if viewModel.showFinishButton {
                TrainingControlSurfaceStyle.surface(
                    in: RoundedRectangle(
                        cornerRadius: capsuleHeight / 2,
                        style: .continuous
                    )
                )
            } else {
                TrainingGlassEffectCompat.roundedRectangleContinuous(
                    cornerRadius: capsuleHeight / 2
                )
            }

            HStack(spacing: 18) {
                if viewModel.showStartButton && (viewModel.currentSet != 0 || viewModel.didJustEditSet) {
                    menuTextItem(
                        text: startButtonTitle,
                        action: onStart,
                        style: .start
                    )
                }

                if viewModel.showFinishButton {
                    menuTextItem(
                        text: AppText.trainingFinish,
                        action: onFinish,
                        style: .finish
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: capsuleHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: capsuleHeight)
        .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))
    }

    @ViewBuilder
    private func menuTextItem(
        text: LocalizedStringResource,
        accessibilityToken: String = "",
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        let usesCompactSurface = style == .control || style == .done
        let visibleHeight = usesCompactSurface
            ? setControlSurfaceHeight
            : capsuleHeight

        Button(action: action) {
            Text(text)
                .font(AppStyle.Font.bottomBarButtons)
                .foregroundColor(AppStyle.Color.white.opacity(0.98))
                .frame(maxWidth: .infinity, minHeight: visibleHeight, maxHeight: visibleHeight)
                .padding(.horizontal, 2)
                .background(alignment: .center) {
                    if usesCompactSurface {
                        if style == .done {
                            RoundedRectangle(
                                cornerRadius: setControlCornerRadius,
                                style: .continuous
                            )
                            .fill(appColorTheme.accent.black)
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: setControlCornerRadius,
                                    style: .continuous
                                )
                                .stroke(appColorTheme.accent.glow, lineWidth: 1.5)
                            )
                            .padding(.horizontal, setControlSurfaceHorizontalInset)
                        } else {
                            TrainingControlSurfaceStyle.surface(
                                in: RoundedRectangle(
                                    cornerRadius: setControlCornerRadius,
                                    style: .continuous
                                )
                            )
                            .padding(.horizontal, setControlSurfaceHorizontalInset)
                        }
                    }
                }
                .contentShape(Rectangle())
        }
        // The visible active-set surface is 44pt high, while the surrounding
        // Button retains a full 48pt minimum touch target.
        .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
        .contentShape(Rectangle())
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityID(for: style, text: accessibilityToken))
    }

    @ViewBuilder
    private func menuIconItem(
        icon: String,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        glassCircleIconButton(
            assetName: icon,
            renderingMode: .template,
            tint: AppStyle.Color.white,
            accessibilityIdentifier: accessibilityID(for: style, text: ""),
            action: action
        )
    }

    /// Feedback entry-point icon — renders one of three bitmap assets that the
    /// designer ships explicitly per state (`feedback_entry`,
    /// `feedback_entry_draft`, `feedback_entry_done`). All three assets share
    /// the same 1024×1024 canvas with the orange plus-cross centred at
    /// (0.500, 0.499) and (for `.draft` / `.done`) the green badge composited
    /// on top at the same canvas position — so a single uniform render path
    /// is enough; no per-state geometry is needed.
    @ViewBuilder
    private func feedbackIconButton(
        state: FeedbackEntryIconState,
        action: @escaping () -> Void
    ) -> some View {
        glassCircleIconButton(
            assetName: state.assetName,
            renderingMode: .original,
            tint: nil,
            accessibilityIdentifier: accessibilityID(for: .feedback, text: ""),
            action: action
        )
        .accessibilityLabel(state.accessibilityLabel)
    }

    /// Shared chrome for every round surface icon button in the bottom bar
    /// (Quick-Done, Feedback). The timer-matched transparent surface keeps the
    /// two entry points visually aligned with the secondary training controls.
    private func glassCircleIconButton(
        assetName: String,
        renderingMode: Image.TemplateRenderingMode,
        tint: Color?,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                TrainingControlSurfaceStyle.surface(in: Circle())

                Image(assetName)
                    .renderingMode(renderingMode)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .foregroundColor(tint)
            }
        }
        .frame(width: Self.glassCircleSize, height: Self.glassCircleSize)
        .contentShape(Circle())
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    // MARK: - Round icon button geometry

    /// Outer tap-target / surface-circle diameter. Matches the bottom-bar
    /// capsule's minimum height (`capsuleHeight = max(48, ...)`) so the
    /// circular Quick-Done / Feedback buttons line up flush with the capsule
    /// they sit next to in the same `HStack`. Also exceeds Apple HIG's 44pt
    /// minimum tap target.
    private static let glassCircleSize: CGFloat = 48
    /// Image render size inside the circular surface. ~67% of the diameter
    /// (Apple HIG glyph-in-circle proportion) so the icon visually breathes
    /// and the frame-less surface background isn't stretched by the image.
    private static let iconSize: CGFloat = 32

    private func accessibilityID(for style: MenuItemStyle, text: String) -> String {
        switch style {
        case .done:      return TrainingIDs.doneButton
        case .finish:    return TrainingIDs.finishButton
        case .start:     return TrainingIDs.startButton
        case .allDone:   return TrainingIDs.allDoneButton
        case .control:   return TrainingIDs.controlButton(text)
        case .quickDone: return TrainingIDs.quickDoneButton
        case .feedback:  return TrainingIDs.feedbackButton
        }
    }

    private var startButtonTitle: LocalizedStringResource {
        switch viewModel.startButtonLabel {
        case .training: AppText.trainingStart
        case .left(let number): AppText.trainingStartLeft(number: number)
        case .right(let number): AppText.trainingStartRight(number: number)
        case .set(let number): AppText.trainingStartSet(number: number)
        }
    }
}
