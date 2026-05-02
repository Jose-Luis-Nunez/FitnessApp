import SwiftUI
import FitnessCore
import FitnessUI
#if canImport(UIKit)
import UIKit
#endif

public struct BottomActionBarView: View {
    public let viewModel: BottomActionBarViewModel
    public let onStart: () -> Void
    public let onCompleteSet: () -> Void
    public let onQuickDone: () -> Void
    public let onCategoryReset: () -> Void
    public let onEditLess: () -> Void
    public let onEditMore: () -> Void
    public let onFinish: () -> Void
    public let onAddExercise: () -> Void
    public let onResetAllExercises: () -> Void
    public let onOpenFeedback: () -> Void
    public let feedbackIconState: FeedbackEntryIconState

    private let barHeight: CGFloat = 0
    private let backgroundColor = AppStyle.Color.backgroundColor

    public init(
        viewModel: BottomActionBarViewModel,
        onStart: @escaping () -> Void,
        onCompleteSet: @escaping () -> Void,
        onQuickDone: @escaping () -> Void,
        onCategoryReset: @escaping () -> Void,
        onEditLess: @escaping () -> Void,
        onEditMore: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onAddExercise: @escaping () -> Void,
        onResetAllExercises: @escaping () -> Void,
        onOpenFeedback: @escaping () -> Void = {},
        feedbackIconState: FeedbackEntryIconState = .entry
    ) {
        self.viewModel = viewModel
        self.onStart = onStart
        self.onCompleteSet = onCompleteSet
        self.onQuickDone = onQuickDone
        self.onCategoryReset = onCategoryReset
        self.onEditLess = onEditLess
        self.onEditMore = onEditMore
        self.onFinish = onFinish
        self.onAddExercise = onAddExercise
        self.onResetAllExercises = onResetAllExercises
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
                    onCategoryReset: onCategoryReset,
                    onEditLess: onEditLess,
                    onEditMore: onEditMore,
                    onFinish: onFinish,
                    onAddExercise: onAddExercise,
                    onResetAllExercises: onResetAllExercises,
                    onOpenFeedback: onOpenFeedback,
                    feedbackIconState: feedbackIconState,
                    barHeight: barHeight,
                    backgroundColor: backgroundColor
                )
            }
            .background(Color.clear)
            .zIndex(2)
        }
    }
}

public struct FloatingActionButtonsView: View {
    public let viewModel: BottomActionBarViewModel
    public let onStart: () -> Void
    public let onCompleteSet: () -> Void
    public let onQuickDone: () -> Void
    public let onCategoryReset: () -> Void
    public let onEditLess: () -> Void
    public let onEditMore: () -> Void
    public let onFinish: () -> Void
    public let onAddExercise: () -> Void
    public let onResetAllExercises: () -> Void
    public let onOpenFeedback: () -> Void
    public let feedbackIconState: FeedbackEntryIconState
    public let barHeight: CGFloat
    public let backgroundColor: Color

    private var capsuleHeight: CGFloat { max(48, barHeight * 1.6) }
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding
    private var capsuleWidth: CGFloat {
#if os(iOS)
        let defaultWidth = UIScreen.main.bounds.width - (2 * sideMargin)
#else
        let defaultWidth: CGFloat = 340
#endif
        return max(240, defaultWidth - 50)
    }

    private let selectionHeight: CGFloat = 46
    private var selectionWidth: CGFloat { max(selectionHeight, selectionHeight * 2.2 - 6) }
    private let selectionFill = Color.white.opacity(0.12)
    private let bottomOffset: CGFloat = 16

    public init(
        viewModel: BottomActionBarViewModel,
        onStart: @escaping () -> Void,
        onCompleteSet: @escaping () -> Void,
        onQuickDone: @escaping () -> Void,
        onCategoryReset: @escaping () -> Void,
        onEditLess: @escaping () -> Void,
        onEditMore: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onAddExercise: @escaping () -> Void,
        onResetAllExercises: @escaping () -> Void,
        onOpenFeedback: @escaping () -> Void = {},
        feedbackIconState: FeedbackEntryIconState = .entry,
        barHeight: CGFloat,
        backgroundColor: Color
    ) {
        self.viewModel = viewModel
        self.onStart = onStart
        self.onCompleteSet = onCompleteSet
        self.onQuickDone = onQuickDone
        self.onCategoryReset = onCategoryReset
        self.onEditLess = onEditLess
        self.onEditMore = onEditMore
        self.onFinish = onFinish
        self.onAddExercise = onAddExercise
        self.onResetAllExercises = onResetAllExercises
        self.onOpenFeedback = onOpenFeedback
        self.feedbackIconState = feedbackIconState
        self.barHeight = barHeight
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 6) {
                ZStack {
                    TrainingGlassEffectCompat.roundedRectangleContinuous(cornerRadius: capsuleHeight / 2)

                    HStack(spacing: 18) {
                        if viewModel.showStartButton && (viewModel.currentSet != 0 || viewModel.didJustEditSet) {
                            menuTextItem(
                                text: viewModel.startButtonTitle,
                                action: onStart,
                                style: .start
                            )
                        }

                        if viewModel.showSetControls {
                            menuTextItem(
                                text: "Less",
                                action: onEditLess,
                                style: .control
                            )

                            menuTextItem(
                                text: "Done",
                                action: onCompleteSet,
                                style: .done
                            )

                            menuTextItem(
                                text: "More",
                                action: onEditMore,
                                style: .control
                            )
                        }

                        if viewModel.showFinishButton {
                            menuTextItem(
                                text: "Finish",
                                action: onFinish,
                                style: .finish
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: capsuleHeight)
                .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))

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

    @ViewBuilder
    private func glassCapsuleButton(
        text: String,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        Button(action: action) {
            ZStack {
                TrainingGlassEffectCompat.roundedFrameGlass(
                    width: capsuleWidth,
                    height: capsuleHeight,
                    cornerRadius: capsuleHeight / 2
                )

                Text(text)
                    .font(AppStyle.Font.bottomBarButtons)
                    .foregroundColor(AppStyle.Color.white.opacity(0.98))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: capsuleWidth, height: capsuleHeight)
        .accessibilityIdentifier(accessibilityID(for: style, text: text))
    }

    @ViewBuilder
    private func menuTextItem(
        text: String,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(AppStyle.Font.bottomBarButtons)
                .foregroundColor(AppStyle.Color.white.opacity(0.98))
                .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
                .padding(.horizontal, 2)
                .background(alignment: .center) {
                    if style == .done {
                        RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                            .fill(selectionFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .frame(width: selectionWidth, height: selectionHeight)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .accessibilityIdentifier(accessibilityID(for: style, text: text))
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

    /// Shared chrome for every round glass-circle icon button in the bottom
    /// bar (Quick-Done, Feedback): a `circleGlass()` with the standard
    /// 10%-white hairline stroke, a centred bitmap icon, and a 44×44 tap
    /// target. The icon image is sized smaller than the glass circle —
    /// otherwise the frame-less `circleGlass()` would expand to match the
    /// largest sibling in the `ZStack`.
    private func glassCircleIconButton(
        assetName: String,
        renderingMode: Image.TemplateRenderingMode,
        tint: Color?,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                TrainingGlassEffectCompat.circleGlass()
                    .overlay(
                        Circle().stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                    )

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

    // MARK: - Glass-circle icon button geometry

    /// Outer tap-target / glass-circle diameter. Matches the bottom-bar
    /// capsule's minimum height (`capsuleHeight = max(48, ...)`) so the
    /// circular Quick-Done / Feedback buttons line up flush with the capsule
    /// they sit next to in the same `HStack`. Also exceeds Apple HIG's 44pt
    /// minimum tap target.
    private static let glassCircleSize: CGFloat = 48
    /// Image render size inside the glass circle. ~67% of the circle diameter
    /// (Apple HIG glyph-in-circle proportion) so the icon visually breathes
    /// and the frame-less `circleGlass()` isn't stretched by the image.
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
}
