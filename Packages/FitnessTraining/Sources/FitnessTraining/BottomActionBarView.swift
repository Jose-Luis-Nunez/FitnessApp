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

    /// Corner radius of the set-control surfaces: literally the timer card's
    /// radius, so the two cannot look different.
    ///
    /// An earlier attempt scaled this by height on the theory that a shorter
    /// shape needs a smaller radius to match a taller one's proportion. That was
    /// wrong here — it produced 7.5pt and made the button visibly squarer than
    /// the timer. Two shapes sitting in the same view read as the same family
    /// when their radius is the same absolute value, not the same ratio.
    private var setControlCornerRadius: CGFloat {
        AppStyle.CornerRadius.timerCard
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
                        image: Image(systemName: "bolt.fill"),
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
    /// Width reserved for Less/More.
    private let setControlSecondaryWidth: CGFloat = 64
    /// Done's width. Fixed, so it stays a block rather than spanning the bar.
    private let setControlDoneWidth: CGFloat = 176
    /// Gap between Done and its two neighbours.
    private let setControlGap: CGFloat = 14

    /// The three controls form one centred group with fixed gaps. Earlier
    /// versions let spacers *between* the buttons absorb the slack, which pinned
    /// Less/More to the outer edges and moved them whenever the trailing
    /// quick-done circle appeared or disappeared. Putting the slack outside the
    /// group keeps their distance to Done constant in both states.
    private var setControlButtons: some View {
        HStack(spacing: setControlGap) {
            menuTextItem(text: AppText.actionLess, accessibilityToken: "Less", action: onEditLess, style: .control)
                .frame(width: setControlSecondaryWidth)

            menuTextItem(text: AppText.actionDone, action: onCompleteSet, style: .done)
                .frame(width: setControlDoneWidth)

            menuTextItem(text: AppText.actionMore, accessibilityToken: "More", action: onEditMore, style: .control)
                .frame(width: setControlSecondaryWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: capsuleHeight)
    }

    /// The start and finish states retain their existing single, shared
    /// capsule. Only the active-set controls become separate buttons.
    private var primaryActionCapsule: some View {
        // Finish now carries the same filled surface and radius as Done, so the
        // outlined pill that used to sit behind it would double up — and the
        // pill's 24pt clip would round its 12pt corners back off.
        ZStack {
            if !viewModel.showFinishButton {
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
        .clipShape(
            RoundedRectangle(
                cornerRadius: viewModel.showFinishButton
                    ? setControlCornerRadius
                    : capsuleHeight / 2,
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private func menuTextItem(
        text: LocalizedStringResource,
        accessibilityToken: String = "",
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        let usesCompactSurface = style == .control || style == .done || style == .finish
        let visibleHeight = usesCompactSurface
            ? setControlSurfaceHeight
            : capsuleHeight

        Button(action: action) {
            Text(text)
                .font(AppStyle.Font.bottomBarButtons)
                // Less/More are secondary: same dimmed grey as the "kg" and
                // "of N" labels in the set rows. Done keeps a bright label
                // because it owns the accent surface.
                .foregroundColor(
                    style == .control
                        ? AppStyle.Color.idleMetricUnit
                        : AppStyle.Color.white.opacity(0.98)
                )
                .frame(maxWidth: .infinity, minHeight: visibleHeight, maxHeight: visibleHeight)
                .padding(.horizontal, 2)
                .background(alignment: .center) {
                    if usesCompactSurface {
                        if style == .done || style == .finish {
                            RoundedRectangle(
                                cornerRadius: setControlCornerRadius,
                                style: .continuous
                            )
                            .fill(AppStyle.Color.trainingDoneSurface)
                            .padding(.horizontal, setControlSurfaceHorizontalInset)
                        }
                        // Less/More draw no surface at all — plain labels beside
                        // the accented Done button. `TrainingControlSurfaceStyle`
                        // is deliberately left untouched here: the timer surface,
                        // pain grid and symptom chips still rely on it.
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
        image: Image,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        glassCircleIconButton(
            image: image,
            renderingMode: .template,
            // Same dimmed grey as the Less/More labels beside it — it is a
            // secondary affordance, not a primary action.
            tint: AppStyle.Color.idleMetricUnit,
            accessibilityIdentifier: accessibilityID(for: style, text: ""),
            action: action
        )
    }

    /// Feedback entry-point icon — renders one of three bitmap assets that the
    /// designer ships explicitly per state (`feedback_entry_2`,
    /// `feedback_entry_draft`, `feedback_entry_done`). One render path for all
    /// three — same zoom, same centring, no per-state geometry.
    @ViewBuilder
    private func feedbackIconButton(
        state: FeedbackEntryIconState,
        action: @escaping () -> Void
    ) -> some View {
        glassCircleIconButton(
            image: Image(state.assetName),
            // `.template` with the same tint as the Quick-Done icon beside it.
            // `.original` was right while the artwork carried its own orange and
            // green; the states are monochrome line art now, so rendering them
            // as-is only made this one control brighter than its neighbour. The
            // states stay distinguishable by their badge shape, not by colour.
            renderingMode: .template,
            tint: AppStyle.Color.idleMetricUnit,
            accessibilityIdentifier: accessibilityID(for: .feedback, text: ""),
            zoom: Self.feedbackIconZoom,
            // The bitmap artwork reads smaller than an SF Symbol at the same
            // render size, so the feedback entry point gets the larger glyph
            // box to match the optical weight of the controls beside it.
            iconSize: Self.bitmapIconSize,
            action: action
        )
        .accessibilityLabel(state.accessibilityLabel)
    }

    /// Shared chrome for every round surface icon button in the bottom bar
    /// (Quick-Done, Feedback). The timer-matched transparent surface keeps the
    /// two entry points visually aligned with the secondary training controls.
    /// Takes a built `Image` rather than an asset name so SF Symbols and bitmap
    /// assets keep sharing this single render path.
    private func glassCircleIconButton(
        image: Image,
        renderingMode: Image.TemplateRenderingMode,
        tint: Color?,
        accessibilityIdentifier: String,
        /// Scales the fitted artwork about the button's centre. `nil` renders it
        /// at fit size. Above 1 the glyph grows past the frame and is clipped by
        /// the circle; below 1 it shrinks inside it. Use it to bring assets whose
        /// glyph fills a different share of its canvas to one apparent size.
        zoom: CGFloat? = nil,
        iconSize: CGFloat = Self.iconSize,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                TrainingControlSurfaceStyle.surface(in: Circle())

                image
                    .renderingMode(renderingMode)
                    .resizable()
                    // Always `.fit`, so the whole glyph is visible whatever the
                    // asset's aspect. `.fill` crops the long axis away, which
                    // cut the sides off any asset that is not square. Scaling
                    // is `zoom`'s job, not the content mode's.
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoom ?? 1)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(Circle())
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
    private static let iconSize: CGFloat = 26
    /// Render size for the bitmap feedback artwork — larger than `iconSize`
    /// because the drawn figure carries less contrast than a stroked SF Symbol
    /// and needs the extra area to stay readable at 48pt.
    private static let bitmapIconSize: CGFloat = 34
    /// Applies to every feedback icon state.
    private static let feedbackIconZoom: CGFloat = 1.42

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
