
import SwiftUI

struct IdleActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onStart: ((Exercise) -> Void)?
    let isResetEnabled: Bool
    let isActiveSetVisible: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Spacer().frame(height: 4)
            
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: viewModel.displaySeatText,
                onEdit: onEdit,
                exercise: viewModel.exercise,
                isEditable: isEditable,
                onSingleExerciseStart: onStart,
                onSingleExerciseReset: nil,
                isActiveSetVisible: isActiveSetVisible,
                isResetEnabled: isResetEnabled,
                showSeatChip: true
            )
            .padding(.bottom, 6)
            
            HStack {
                AnalyticsSectionView(
                    exercise: viewModel.exercise,
                    viewModel: analyticsViewModel
                )
                
                Spacer()
                
                RightFieldView(
                    field: viewModel.generateStyledFieldData().first(where: {
                        $0.data.field == .edit(.weightChip)
                    })!,
                    exercise: viewModel.exercise,
                    onEdit: onEdit,
                    isEditable: isEditable
                )
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Padding.horizontal)
        .background(AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
    }
}
