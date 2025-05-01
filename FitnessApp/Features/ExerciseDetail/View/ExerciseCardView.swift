import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

struct ExerciseCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void

    var body: some View {
        VStack(spacing: 8) {
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: viewModel.displaySeatText
            )
            
            Divider().background(AppStyle.Color.purpleGrey).padding(.horizontal, 4)
            
            CardBottomSectionView(
                viewModel: viewModel,
                currentReps: viewModel.exercise.reps
            )
            .scaleEffect(1.1)
            .padding(.top, 2)
            
            // Bearbeiten-Button hinzufügen
            Button(action: {
                onEdit(viewModel.exercise) // onEdit aufrufen, wenn der Button geklickt wird
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(AppStyle.Color.white)
                    .padding(8)
                    .background(AppStyle.Color.purpleGrey)
                    .clipShape(Circle())
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(viewModel.exercise.isCompleted ? AppStyle.Color.exerciseCardDoneBackGround : AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
    }
}

struct CardTopSectionView: View {
    let title: String
    let seatText: String
    
    var body: some View {
        HStack(alignment: .top) {
            TextView(
                styled: StyledExerciseField(field: .action(.exerciseCardTitleText)),
                content: title
            ).accessibilityIdentifier(IDS.nameLabel)
            
            Spacer()
            
            AppChipView(
                styled: StyledExerciseField(field: .edit(.seatChip)),
                content: seatText
            )
            .scaleEffect(1.1)
            .accessibilityIdentifier(IDS.seatLabel)
        }
    }
}

struct CardBottomSectionView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let currentReps: Int
    
    var body: some View {
        let styledFields = viewModel.generateStyledFieldData()
        let leftFields = styledFields.filter { $0.style.column == .left }
        let rightField = styledFields.first(where: { $0.style.column == .right })
        
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: -24) {
                AppIconView(styled: StyledExerciseField(field: .action(.analyticsIcon)))
                
                TextView(styled: StyledExerciseField(field: .action(.analyticsText))).offset(x: 10)
            }
            
            Spacer(minLength: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(leftFields) { styled in
                    AppChipView(styled: styled)
                }
            }
            
            if let right = rightField {
                AppChipView(styled: right)
                    .frame(height: right.style.frameHeight)
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
}
