import SwiftUI
import FitnessCore
import FitnessAnalytics
import FitnessUI

// MARK: - Training Session Component

public struct TrainingSessionComponent: View {
    public var coordinator: TrainingCoordinator
    public let onEdit: ((Exercise, ExerciseEditMode) -> Void)?
    public let onReset: ((Exercise) -> Void)?
    public let onCancel: (() -> Void)?
    public let analyticsViewModel: AnalyticsViewModel

    private var dynamicSpacing: CGFloat {
        AppStyle.DeviceLayout.trainingSessionSpacing
    }

    public init(
        coordinator: TrainingCoordinator,
        onEdit: ((Exercise, ExerciseEditMode) -> Void)? = nil,
        onReset: ((Exercise) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        analyticsViewModel: AnalyticsViewModel = AnalyticsViewModel()
    ) {
        self.coordinator = coordinator
        self.onEdit = onEdit
        self.onReset = onReset
        self.onCancel = onCancel
        self.analyticsViewModel = analyticsViewModel
    }

    public var body: some View {
        if let exercise = coordinator.currentExercise {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: dynamicSpacing) {
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

                    CompactTimerComponent(
                        viewModel: coordinator.activeSetViewModel,
                        onCancel: onCancel
                    )
                    .frame(minWidth: 80, maxWidth: 160)
                }
                .padding(.horizontal, AppStyle.Padding.card)
            }
            .padding(.vertical, 0)
        }
    }
}

// MARK: - Compact Timer Component

public struct CompactTimerComponent: View {
    public var viewModel: ActiveSetViewModel
    public let onCancel: (() -> Void)?

    public init(viewModel: ActiveSetViewModel, onCancel: (() -> Void)?) {
        self.viewModel = viewModel
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text(max(viewModel.timerSeconds, 0).formattedAsTimer)
                .font(.system(size: AppStyle.DeviceLayout.timerFontSize, weight: .bold))
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer()
                .frame(maxHeight: 10)

            Button(action: {
                if let onCancel = onCancel {
                    onCancel()
                } else {
                    viewModel.cancelActiveSet()
                }
            }) {
                Text("Cancel")
                    .font(AppStyle.Font.tileValue)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppStyle.Color.green)
                    .cornerRadius(AppStyle.CornerRadius.timerCard)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.timerCard)
                .fill(AppStyle.Color.greenBlack)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.timerCard)
                        .stroke(AppStyle.Color.greenGlow, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Training Action Bar Component

public struct TrainingActionBarComponent: View {
    public var coordinator: TrainingCoordinator
    public let exercises: [Exercise]
    public let hasActiveExercise: Bool

    public init(coordinator: TrainingCoordinator, exercises: [Exercise], hasActiveExercise: Bool) {
        self.coordinator = coordinator
        self.exercises = exercises
        self.hasActiveExercise = hasActiveExercise
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
            onCompleteAllQuickDone: originalCallbacks.onCompleteAllQuickDone,
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
            onResetAllExercises: originalCallbacks.onResetAllExercises
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
                onCompleteAllQuickDone: trainingCallbacks.onCompleteAllQuickDone,
                onCategoryReset: trainingCallbacks.onCategoryReset,
                onEditLess: trainingCallbacks.onEditLess,
                onEditMore: trainingCallbacks.onEditMore,
                onFinish: trainingCallbacks.onFinish,
                onAddExercise: trainingCallbacks.onAddExercise,
                onResetAllExercises: trainingCallbacks.onResetAllExercises
            )
            .zIndex(5)
            .onChange(of: currentViewModel.isLastSetCompleted) { _ in
            }
            .onChange(of: currentViewModel.isSetInProgress) { _ in
            }
            .onChange(of: currentViewModel.currentSet) { _ in
            }
        }
    }
}
