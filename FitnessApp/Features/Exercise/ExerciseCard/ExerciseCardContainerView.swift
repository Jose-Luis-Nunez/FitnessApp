import SwiftUI

struct ExerciseCardContainerView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @ObservedObject var activeSetViewModel: ActiveSetViewModel
    let onStart: ((Exercise) -> Void)?
    let onReset: ((Exercise) -> Void)?
    let isActiveSetVisible: Bool
    let isResetEnabled: Bool
    
    var body: some View {
        if viewModel.exercise.isCompleted {
            InactiveCardView(
                viewModel: viewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel,
                onReset: onReset,
                isResetEnabled: true
            )
        } else if activeSetViewModel.currentExercise?.id == viewModel.exercise.id {
            ActiveCardView(
                viewModel: viewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel,
                onStart: onStart,
                onReset: onReset,
                isActiveSetVisible: isActiveSetVisible,
                isResetEnabled: isResetEnabled
            )
        } else {
            IdleActiveCardView(
                viewModel: viewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel,
                onStart: onStart,
                isResetEnabled: isResetEnabled,
                isActiveSetVisible: isActiveSetVisible
            )
        }
    }
}
