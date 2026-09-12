import SwiftUI
import FitnessCore
import FitnessResources
import FitnessStorage
import FitnessUI
import Factory

// MARK: - Training Session Component

private struct ActiveSetScrollTarget: Equatable, Sendable {
    let id: SetProgress.ID
    let logicalSetIndex: Int
}

public struct TrainingSessionComponent: View {
    public var coordinator: TrainingCoordinator
    public let onEdit: ((Exercise, ExerciseEditMode) -> Void)?
    public let onCancel: (() -> Void)?
    public let muscleArtwork: Image?
    @State private var hasPositionedSetScroller = false

    private let visibleLogicalSetCount = 3

    private var dynamicSpacing: CGFloat {
        AppStyle.DeviceLayout.trainingSessionSpacing
    }

    public init(
        coordinator: TrainingCoordinator,
        onEdit: ((Exercise, ExerciseEditMode) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        muscleArtwork: Image? = nil
    ) {
        self.coordinator = coordinator
        self.onEdit = onEdit
        self.onCancel = onCancel
        self.muscleArtwork = muscleArtwork
    }

    public var body: some View {
        if let exercise = coordinator.currentExercise {
            session(exercise)
        }
    }

    private func session(_ exercise: Exercise) -> some View {
        GeometryReader { geometry in
            sessionColumns(exercise, availableWidth: geometry.size.width)
                .frame(width: geometry.size.width, alignment: .leading)
        }
        .frame(height: sessionHeight(for: exercise))
    }

    private func sessionColumns(
        _ exercise: Exercise,
        availableWidth: CGFloat
    ) -> some View {
        let isBilateral = exercise.executionMode == .bilateral
        // Bilateral rows need the width for their L/R pairs, so the artwork
        // stays a narrow rail there. The standard layout gives the figure a
        // real column: values on the left, the body on the right. The values
        // may run over the figure's leading edge — that part of the artwork
        // is empty background — so the rail is not shrunk to make room.
        let railWidth = isBilateral
            ? min(
                AppStyle.Layout.trainingSheetRailMinimumWidth,
                max(
                    AppStyle.Layout.trainingSheetBilateralRailMinimumWidth,
                    availableWidth * 0.22
                )
            )
            : min(
                AppStyle.Layout.trainingSheetArtworkRailMaximumWidth,
                max(
                    AppStyle.Layout.trainingSheetRailMinimumWidth,
                    availableWidth * AppStyle.Layout.trainingSheetArtworkRailFraction
                )
            )
        let horizontalPadding = isBilateral
            ? AppStyle.Layout.trainingSheetBilateralContentHorizontalPadding
            : min(
                AppStyle.Layout.trainingSheetContentHorizontalPadding,
                max(
                    AppStyle.Layout.trainingSheetContentMinimumHorizontalPadding,
                    AppStyle.Layout.trainingSheetContentMinimumHorizontalPadding
                        + max(availableWidth - 320, 0) * 0.16
                )
            )
        let columnSpacing = isBilateral
            ? AppStyle.Layout.bilateralMetricSpacingCompact
            : dynamicSpacing
        let scrollTarget = activeSetScrollTarget(for: exercise)
        // A `ZStack`, not an `HStack`: the values column spans the full width
        // and the artwork rail sits on top at the trailing edge, so long rows
        // overlap the figure's empty leading margin instead of squeezing it.
        return ZStack(alignment: .topTrailing) {
            // Artwork first, so the values draw over its empty leading margin
            // rather than disappearing under the figure.
            artworkRail(exercise, railWidth: railWidth)

            VStack(alignment: .leading, spacing: AppStyle.Padding.titleBottom) {
                VStack(alignment: .leading, spacing: 2) {
                    // The eyebrow: which category this exercise belongs to,
                    // small and wide-tracked so it labels the title rather
                    // than competing with it.
                    Text(exercise.category.localizedName)
                        .font(AppStyle.Font.trainingCategoryEyebrow)
                        .textCase(.uppercase)
                        .tracking(2.5)
                        .foregroundColor(AppStyle.Color.idleMetricUnit)
                        .lineLimit(1)
                        .accessibilityIdentifier(TrainingIDs.sheetCategory)

                    Text(exercise.name)
                        .font(AppStyle.Font.navigationHeadline)
                        .foregroundColor(AppStyle.Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier(TrainingIDs.sheetTitle)
                }
                .padding(.leading, Self.titleLeadingInset)

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        activeSetView(exercise)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    // Standard rows hug their content: a `ScrollView` hit-tests
                    // its whole frame, and one spanning the column would sit
                    // over the figure and swallow the tap that opens the seat
                    // picker. Bilateral rows are width-aware layouts and keep
                    // the full column.
                    .fixedSize(horizontal: !isBilateral, vertical: false)
                    .frame(height: setViewportHeight(for: exercise), alignment: .top)
                    .offset(y: AppStyle.Layout.trainingSheetSetVerticalOffset)
                    .accessibilityIdentifier(TrainingIDs.setScroll)
                    .onAppear {
                        positionSetScroller(
                            proxy,
                            target: scrollTarget,
                            animated: false
                        )
                        hasPositionedSetScroller = true
                    }
                    .onChange(of: scrollTarget) { _, newTarget in
                        guard hasPositionedSetScroller else { return }
                        positionSetScroller(
                            proxy,
                            target: newTarget,
                            animated: true
                        )
                    }
                }
            }
            // The whole values column steps in from the sheet edge. Title and
            // rows move together, so their shared edge is preserved.
            .padding(
                .leading,
                isBilateral
                    ? AppStyle.Layout.trainingSheetBilateralValuesColumnLeadingInset
                    : AppStyle.Layout.trainingSheetValuesColumnLeadingInset
            )
            // Bilateral keeps the two side by side; the rail's width is taken
            // off the column so the L/R pairs never run under the figure.
            // Standard may run over the figure but must stop short of the dial
            // column: a `ScrollView` hit-tests its whole frame, empty space
            // included, and would swallow taps meant for Cancel and Quick-Done.
            .padding(
                .trailing,
                isBilateral
                    ? railWidth + columnSpacing
                    : AppStyle.Layout.trainingDialSmallDiameter
                        + AppStyle.Layout.trainingDialTrailingInset
                        + AppStyle.Layout.trainingDialColumnClearance
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, horizontalPadding)
    }

    /// Standard: the figure fills the whole column height and the timer pill
    /// hangs over it from the top-trailing corner, instead of in a slot below
    /// it. That is what lets the figure be this large: nothing else claims
    /// height in the rail. Bilateral rows leave only a narrow rail, where a
    /// full-height figure is a cropped strip with a pill over it, so that mode
    /// keeps the square icon with the timer and Quick-Done stacked below.
    @ViewBuilder
    private func artworkRail(_ exercise: Exercise, railWidth: CGFloat) -> some View {
        if exercise.executionMode == .bilateral {
            stackedRail(exercise, railWidth: railWidth)
        } else {
            overlaidRail(exercise, railWidth: railWidth)
        }
    }

    private func stackedRail(_ exercise: Exercise, railWidth: CGFloat) -> some View {
        VStack(spacing: dynamicSpacing) {
            ExerciseMuscleIconView(
                iconName: exercise.displayIconName,
                alignment: exercise.iconAlignment,
                allowsEditing: exercise.allowsSeatEditing,
                accessibilityIdentifier: TrainingIDs.muscleIcon,
                size: railWidth,
                showsGlow: false,
                artwork: muscleArtwork,
                onEdit: { onEdit?(exercise, .seat) }
            )
            .frame(height: railWidth)

            CompactTimerComponent(
                viewModel: coordinator.activeSetViewModel,
                onCancel: onCancel
            )
            .frame(height: AppStyle.Layout.trainingSheetBilateralTimerHeight)

            if showsQuickDone {
                TrainingQuickDoneDial(
                    diameter: AppStyle.Layout.trainingDialSmallDiameter,
                    action: quickDoneAction
                )
            }
        }
        .frame(width: railWidth, alignment: .top)
    }

    private func overlaidRail(_ exercise: Exercise, railWidth: CGFloat) -> some View {
        let railHeight = sessionHeight(for: exercise)
        return ZStack(alignment: .topTrailing) {
            ExerciseMuscleIconView(
                iconName: exercise.displayIconName,
                alignment: exercise.iconAlignment,
                allowsEditing: exercise.allowsSeatEditing,
                accessibilityIdentifier: TrainingIDs.muscleIcon,
                size: railWidth,
                height: railHeight,
                // Upper-body categories zoom into the torso; legs keep the
                // full figure because their focus is at the bottom.
                zoom: exercise.category == .legs
                    ? 1
                    : AppStyle.Layout.trainingSheetArtworkUpperBodyZoom,
                showsGlow: false,
                artwork: muscleArtwork,
                onEdit: { onEdit?(exercise, .seat) }
            )
            .frame(width: railWidth, height: railHeight)

            // The timer pill with Quick-Done under it, hung from the top of
            // the rail at shoulder height. Quick-Done is here and not in the
            // Less/Done/More bar so the two share one trailing edge.
            VStack(alignment: .trailing, spacing: AppStyle.Layout.trainingDialSpacing) {
                TrainingTimerPill(
                    viewModel: coordinator.activeSetViewModel,
                    width: AppStyle.Layout.trainingDialSmallDiameter,
                    onCancel: {
                        if let onCancel {
                            onCancel()
                        } else {
                            coordinator.activeSetViewModel.cancelActiveSet()
                        }
                    }
                )

                if showsQuickDone {
                    TrainingQuickDoneDial(
                        diameter: AppStyle.Layout.trainingDialSmallDiameter,
                        action: quickDoneAction
                    )
                }
            }
            .padding(.trailing, AppStyle.Layout.trainingDialTrailingInset)
            .padding(.top, AppStyle.Layout.trainingDialTopInset)
        }
        .frame(width: railWidth, height: railHeight, alignment: .topTrailing)
    }

    /// The rule lives on `BottomActionBarViewModel`; the sheet only reads it.
    private var showsQuickDone: Bool {
        coordinator.createBottomActionBarViewModel(
            hasActiveExercise: coordinator.isTrainingActive
        ).showsQuickDone
    }

    private var quickDoneAction: () -> Void {
        coordinator.createTrainingCallbacks().onQuickDone
    }

    /// The exercise name heads the same column as the set rows. The rows are
    /// inset once, by `SimpleActiveSetView` itself; the standard row adds
    /// nothing, the bilateral layout pads its whole stack once more. The title
    /// matches the standard row's leading edge, which is the progress rail's
    /// marker; "Set N" sits `setRailToLabelSpacing` further in on purpose.
    private static var titleLeadingInset: CGFloat {
        AppStyle.DeviceLayout.cardPadding
    }

    private func setViewportHeight(for exercise: Exercise) -> CGFloat {
        exercise.executionMode == .bilateral
            ? AppStyle.Layout.trainingSheetBilateralSetViewportHeight
            : AppStyle.Layout.trainingSheetStandardSetViewportHeight
    }

    private func sessionHeight(for exercise: Exercise) -> CGFloat {
        exercise.executionMode == .bilateral
            ? AppStyle.Layout.trainingSheetBilateralSessionHeight
            : AppStyle.Layout.trainingSheetStandardSessionHeight
    }

    private func activeSetScrollTarget(
        for exercise: Exercise
    ) -> ActiveSetScrollTarget? {
        let viewModel = coordinator.activeSetViewModel
        let progress = viewModel.setProgress

        guard !viewModel.quickDoneAllCompleted,
              progress.indices.contains(viewModel.activeSetIndex) else {
            return nil
        }

        let activeProgress = progress[viewModel.activeSetIndex]
        let logicalSetIndex = activeProgress.logicalSetIndex
            ?? viewModel.activeSetIndex

        guard exercise.executionMode == .bilateral else {
            return ActiveSetScrollTarget(
                id: activeProgress.id,
                logicalSetIndex: logicalSetIndex
            )
        }

        let pairTarget = progress.first {
            $0.logicalSetIndex == logicalSetIndex && $0.side == .left
        }
        return ActiveSetScrollTarget(
            id: pairTarget?.id ?? activeProgress.id,
            logicalSetIndex: logicalSetIndex
        )
    }

    private func positionSetScroller(
        _ proxy: ScrollViewProxy,
        target: ActiveSetScrollTarget?,
        animated: Bool
    ) {
        guard let target,
              target.logicalSetIndex >= visibleLogicalSetCount else {
            return
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(target.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target.id, anchor: .bottom)
        }
    }

    private func activeSetView(_ exercise: Exercise) -> some View {
        SimpleActiveSetView(
            exercise: exercise,
            setProgress: Binding(
                get: { coordinator.activeSetViewModel.setProgress },
                set: { coordinator.activeSetViewModel.setProgress = $0 }
            ),
            viewModel: coordinator.activeSetViewModel
        )
        .layoutPriority(1)
        .onAppear {
            if coordinator.activeSetViewModel.isSetInProgress {
                coordinator.activeSetViewModel.startTimer()
            }
        }
    }
}

// MARK: - Compact Timer Component

public struct CompactTimerComponent: View {
    public var viewModel: ActiveSetViewModel
    public let onCancel: (() -> Void)?

    public init(
        viewModel: ActiveSetViewModel,
        onCancel: (() -> Void)?
    ) {
        self.viewModel = viewModel
        self.onCancel = onCancel
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: AppStyle.CornerRadius.timerCard,
            style: .continuous
        )
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: max(viewModel.timerSeconds, 0).formattedAsTimer)
                .font(AppStyle.Font.trainingTimerLarge)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Button(action: {
                if let onCancel = onCancel {
                    onCancel()
                } else {
                    viewModel.cancelActiveSet()
                }
            }) {
                Text(AppText.trainingCancel)
                    .font(AppStyle.Font.trainingTimerCancel)
                    .foregroundColor(AppStyle.Color.idleMetricLabel)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(FitnessCore.TrainingIDs.cancelTraining)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        // A dark fill under the outline keeps the digits readable; the shared
        // control surface stays outline-only for the pain grid and symptom
        // chips that also use it.
        .background {
            surfaceShape
                .fill(AppStyle.Color.black.opacity(AppStyle.Opacity.trainingTimerBackdrop))
        }
        .overlay {
            TrainingControlSurfaceStyle.surface(in: surfaceShape)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Training Action Bar Component

public struct TrainingActionBarComponent: View {
    public var coordinator: TrainingCoordinator
    public let hasActiveExercise: Bool

    @Injected(\.feedbackStorage) private var feedbackStorage: FeedbackStoring

    public init(coordinator: TrainingCoordinator, exercises _: [Exercise], hasActiveExercise: Bool) {
        self.coordinator = coordinator
        self.hasActiveExercise = hasActiveExercise
    }

    /// Computes the entry-icon state for the currently focused exercise's
    /// **active session**. Read inside `body` so any change to
    /// `coordinator.draftStore.current`, `coordinator.focusedExerciseId`, or
    /// the underlying storage triggers a recomputation via SwiftUI's
    /// observation tracking.
    private var feedbackIconState: FeedbackEntryIconState {
        guard let exerciseId = coordinator.currentExercise?.id else { return .entry }
        return FeedbackEntryIconResolver.state(
            for: exerciseId,
            sessionId: coordinator.currentSessionId(for: exerciseId),
            draftStore: coordinator.draftStore,
            storage: feedbackStorage
        )
    }

    private var bottomActionBarViewModel: BottomActionBarViewModel {
        coordinator.createBottomActionBarViewModel(hasActiveExercise: hasActiveExercise)
    }

    private var trainingCallbacks: TrainingCallbacks {
        let originalCallbacks = coordinator.createTrainingCallbacks()

        return TrainingCallbacks(
            onStart: originalCallbacks.onStart,
            onCompleteSet: {
                originalCallbacks.onCompleteSet()
            },
            onQuickDone: originalCallbacks.onQuickDone,
            onCategoryReset: originalCallbacks.onCategoryReset,
            onEditLess: {
                guard coordinator.activeSetViewModel.isSetInProgress ||
                    coordinator.activeSetViewModel.setProgress.count > 0 else {
                    return
                }
                originalCallbacks.onEditLess()
            },
            onEditMore: {
                guard coordinator.activeSetViewModel.isSetInProgress ||
                    coordinator.activeSetViewModel.setProgress.count > 0 else {
                    return
                }
                originalCallbacks.onEditMore()
            },
            onFinish: originalCallbacks.onFinish,
            onAddExercise: originalCallbacks.onAddExercise,
            onResetAllExercises: originalCallbacks.onResetAllExercises,
            onOpenFeedback: originalCallbacks.onOpenFeedback
        )
    }

    public var body: some View {
        let currentViewModel = coordinator.activeSetViewModel
        let viewModel = bottomActionBarViewModel

        // Kept in the layout while a set is being edited and only made inert.
        // Removing it shrank the training sheet at the exact moment the
        // Less/More sheet opens: the card behind dropped down while the picker
        // slid up over it, which read as a two-step lurch rather than one
        // movement. Opening the feedback sheet never triggered this, which is
        // why that transition always felt smooth. The picker covers this bar
        // completely, so keeping it rendered costs nothing visually.
        if viewModel.shouldShow {
            BottomActionBarView(
                viewModel: viewModel,
                onStart: trainingCallbacks.onStart,
                onCompleteSet: trainingCallbacks.onCompleteSet,
                onEditLess: trainingCallbacks.onEditLess,
                onEditMore: trainingCallbacks.onEditMore,
                onFinish: trainingCallbacks.onFinish,
                onOpenFeedback: trainingCallbacks.onOpenFeedback,
                feedbackIconState: feedbackIconState
            )
            // Both are required: `allowsHitTesting` stops touches, but the
            // subtree would stay VoiceOver-focusable and XCUITest-tappable
            // behind the modal picker, and activating it that way would still
            // run the callbacks.
            .allowsHitTesting(!currentViewModel.isEditing)
            .accessibilityHidden(currentViewModel.isEditing)
            .zIndex(5)
        }
    }
}
