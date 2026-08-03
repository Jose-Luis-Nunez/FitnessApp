import SwiftUI
import FitnessCore
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
        let railWidth = isBilateral
            ? min(
                AppStyle.Layout.trainingSheetRailMinimumWidth,
                max(
                    AppStyle.Layout.trainingSheetBilateralRailMinimumWidth,
                    availableWidth * 0.22
                )
            )
            : min(
                AppStyle.Layout.trainingSheetRailMaximumWidth,
                max(
                    AppStyle.Layout.trainingSheetRailMinimumWidth,
                    availableWidth * 0.28
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
        return HStack(alignment: .top, spacing: columnSpacing) {
            VStack(alignment: .leading, spacing: AppStyle.Padding.titleBottom) {
                Text(exercise.name)
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier(TrainingIDs.sheetTitle)

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        activeSetView(exercise)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

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
                    onCancel: onCancel,
                    expanded: exercise.executionMode == .bilateral
                )
                .frame(height: timerHeight(for: exercise))
            }
            .frame(width: railWidth, alignment: .top)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private func setViewportHeight(for exercise: Exercise) -> CGFloat {
        exercise.executionMode == .bilateral
            ? AppStyle.Layout.trainingSheetBilateralSetViewportHeight
            : AppStyle.Layout.trainingSheetStandardSetViewportHeight
    }

    private func timerHeight(for exercise: Exercise) -> CGFloat {
        exercise.executionMode == .bilateral
            ? AppStyle.Layout.trainingSheetBilateralTimerHeight
            : AppStyle.Layout.trainingSheetTimerHeight
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
    public let expanded: Bool

    public init(
        viewModel: ActiveSetViewModel,
        onCancel: (() -> Void)?,
        expanded: Bool = false
    ) {
        self.viewModel = viewModel
        self.onCancel = onCancel
        self.expanded = expanded
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(max(viewModel.timerSeconds, 0).formattedAsTimer)
                .font(
                    expanded
                        ? AppStyle.Font.trainingTimerLarge
                        : AppStyle.Font.trainingTimer
                )
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
                Text("Cancel")
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
        .overlay {
            TrainingControlSurfaceStyle.surface(
                in: RoundedRectangle(
                    cornerRadius: AppStyle.CornerRadius.timerCard,
                    style: .continuous
                )
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Training Action Bar Component

public struct TrainingActionBarComponent: View {
    public var coordinator: TrainingCoordinator
    public let exercises: [Exercise]
    public let hasActiveExercise: Bool

    @Injected(\.feedbackStorage) private var feedbackStorage: FeedbackStoring

    public init(coordinator: TrainingCoordinator, exercises: [Exercise], hasActiveExercise: Bool) {
        self.coordinator = coordinator
        self.exercises = exercises
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
        coordinator.createBottomActionBarViewModel(
            exercises: exercises,
            hasActiveExercise: hasActiveExercise
        )
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

        if viewModel.shouldShow && !currentViewModel.isEditing {
            BottomActionBarView(
                viewModel: viewModel,
                onStart: trainingCallbacks.onStart,
                onCompleteSet: trainingCallbacks.onCompleteSet,
                onQuickDone: trainingCallbacks.onQuickDone,
                onCategoryReset: trainingCallbacks.onCategoryReset,
                onEditLess: trainingCallbacks.onEditLess,
                onEditMore: trainingCallbacks.onEditMore,
                onFinish: trainingCallbacks.onFinish,
                onAddExercise: trainingCallbacks.onAddExercise,
                onResetAllExercises: trainingCallbacks.onResetAllExercises,
                onOpenFeedback: trainingCallbacks.onOpenFeedback,
                feedbackIconState: feedbackIconState
            )
            .zIndex(5)
        }
    }
}
