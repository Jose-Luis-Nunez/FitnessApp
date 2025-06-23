import SwiftUI

struct InactiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onReset: ((Exercise) -> Void)?
    let isResetEnabled: Bool

    var body: some View {
        VStack(spacing: 2) {
            Spacer().frame(height: 4)
            
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: viewModel.displaySeatText,
                onEdit: onEdit,
                exercise: viewModel.exercise,
                isEditable: isEditable,
                onStart: nil,
                onReset: onReset,
                isActiveSetVisible: false,
                isResetEnabled: isResetEnabled
            ).padding(.bottom, 6)
            
            Divider().background(AppStyle.Color.purpleGrey).padding(.horizontal, 4)
            
            CardBottomSectionView(
                viewModel: viewModel,
                currentReps: viewModel.exercise.reps,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel
            )
            .padding(.top, 0)
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Padding.horizontal)
        .background(AppStyle.Color.black)
        .cornerRadius(AppStyle.CornerRadius.card)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                .stroke(AppStyle.Color.green, lineWidth: 2)
        )
        .offset(y: 10)
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: viewModel.exercise.isCompleted)
    }
}
