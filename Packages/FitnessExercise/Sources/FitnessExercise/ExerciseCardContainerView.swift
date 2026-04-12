import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessTraining

public enum CardVariant: Equatable, Sendable {
    case completed
    case active
    case idle
}

public struct ExerciseCardContainerView: View {
    public var viewModel: ExerciseCardViewModel
    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public var analyticsViewModel: AnalyticsViewModel
    public var activeSetViewModel: ActiveSetViewModel
    public let onStart: ((Exercise) -> Void)?
    public let onReset: ((Exercise) -> Void)?
    public let isActiveSetVisible: Bool
    public let isResetEnabled: Bool
    public let isInProgress: Bool

    public init(
        viewModel: ExerciseCardViewModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel,
        activeSetViewModel: ActiveSetViewModel,
        onStart: ((Exercise) -> Void)?,
        onReset: ((Exercise) -> Void)?,
        isActiveSetVisible: Bool,
        isResetEnabled: Bool,
        isInProgress: Bool = false
    ) {
        self.viewModel = viewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
        self.activeSetViewModel = activeSetViewModel
        self.onStart = onStart
        self.onReset = onReset
        self.isActiveSetVisible = isActiveSetVisible
        self.isResetEnabled = isResetEnabled
        self.isInProgress = isInProgress
    }

    public static func resolveVariant(
        isCompleted: Bool,
        isActiveSetVisible: Bool,
        activeExerciseId: UUID?,
        exerciseId: UUID
    ) -> CardVariant {
        if isCompleted { return .completed }
        if isActiveSetVisible, activeExerciseId == exerciseId { return .active }
        return .idle
    }

    public var body: some View {
        let variant = Self.resolveVariant(
            isCompleted: viewModel.exercise.isCompleted,
            isActiveSetVisible: isActiveSetVisible,
            activeExerciseId: activeSetViewModel.currentExercise?.id,
            exerciseId: viewModel.exercise.id
        )

        switch variant {
        case .completed:
            InactiveCardView(
                viewModel: viewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel,
                onReset: onReset,
                isResetEnabled: true
            )
            .accessibilityIdentifier(ExerciseCardIDs.completedCard(viewModel.exercise.id))
        case .active:
            ActiveCardView(
                viewModel: viewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel
            )
            .accessibilityIdentifier(ExerciseCardIDs.activeCard(viewModel.exercise.id))
        case .idle:
            IdleActiveCardView(
                viewModel: viewModel,
                analyticsViewModel: analyticsViewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                onStart: onStart,
                isInProgress: isInProgress
            )
            .accessibilityIdentifier(ExerciseCardIDs.idleCard(viewModel.exercise.id))
        }
    }
}
