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
    public let onCompleteAllQuickDone: () -> Void
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
        onCompleteAllQuickDone: @escaping () -> Void,
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
        self.onCompleteAllQuickDone = onCompleteAllQuickDone
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
                    onCompleteAllQuickDone: onCompleteAllQuickDone,
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
    public let onCompleteAllQuickDone: () -> Void
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
        onCompleteAllQuickDone: @escaping () -> Void,
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
        self.onCompleteAllQuickDone = onCompleteAllQuickDone
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
            if viewModel.showQuickDoneBeendenButton {
                HStack(spacing: 6) {
                    glassCapsuleButton(
                        text: "Beenden",
                        action: onFinish,
                        style: .finish
                    )
                    .frame(maxWidth: .infinity)

                    feedbackIconButton(state: feedbackIconState, action: onOpenFeedback)
                }
            } else if viewModel.showQuickDoneDoneButton {
                glassCapsuleButton(
                    text: "All Done",
                    action: onCompleteAllQuickDone,
                    style: .allDone
                )
            } else {
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
                                    text: "Beenden",
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
        Button(action: action) {
            ZStack {
                TrainingGlassEffectCompat.circleGlass()
                    .overlay(
                        Circle().stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                    )

                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID(for: style, text: ""))
    }

    /// Feedback entry-point icon — renders one of three bitmap assets that the
    /// designer ships explicitly per state:
    ///   - `.entry` → `feedback_entry`
    ///   - `.draft` → `feedback_entry_draft`
    ///   - `.done`  → `feedback_entry_done`
    /// The assets are rendered in their **original** mode (no template tint)
    /// so the per-state colour baked into each PNG is preserved.
    @ViewBuilder
    private func feedbackIconButton(
        state: FeedbackEntryIconState,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                TrainingGlassEffectCompat.circleGlass()
                    .overlay(
                        Circle().stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                    )

                Image(assetName(for: state))
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
            }
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID(for: .feedback, text: ""))
        .accessibilityLabel(accessibilityLabel(for: state))
    }

    private func assetName(for state: FeedbackEntryIconState) -> String {
        switch state {
        case .entry: return "feedback_entry"
        case .draft: return "feedback_entry_draft"
        case .done:  return "feedback_entry_done"
        }
    }

    private func accessibilityLabel(for state: FeedbackEntryIconState) -> String {
        switch state {
        case .entry: return "Add feedback"
        case .draft: return "Feedback draft in progress"
        case .done:  return "Feedback saved"
        }
    }

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
