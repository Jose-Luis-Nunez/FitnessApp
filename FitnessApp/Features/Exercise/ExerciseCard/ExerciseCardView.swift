import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

struct ExerciseCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Spacer().frame(height: 8)

            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: viewModel.displaySeatText
            )
            
            Divider().background(AppStyle.Color.purpleGrey).padding(.horizontal, 4)
            
            CardBottomSectionView(
                viewModel: viewModel,
                currentReps: viewModel.exercise.reps,
                onEdit: onEdit,
                isEditable: isEditable
            )
            .padding(.top, 0)
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Padding.horizontal)
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
            )
            .frame(maxWidth: 200, maxHeight: 20, alignment: .leading)
            .accessibilityIdentifier(IDS.nameLabel)
            
            Spacer()
            
            AppChipView(
                styled: StyledExerciseField(field: .edit(.seatChip)),
                content: seatText,
                onTap: nil
            )
            .frame(width: 60)
            .accessibilityIdentifier(IDS.seatLabel)
        }
    }
}

struct CardBottomSectionView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let currentReps: Int
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    
    var body: some View {
        let styledFields = viewModel.generateStyledFieldData()
        let leftFields = styledFields.filter { $0.style.column == .left }
        let rightField = styledFields.first(where: { $0.style.column == .right })
        
        HStack(alignment: .center, spacing: 8) {
            AnalyticsSectionView()
            .offset(x: -AppStyle.Padding.horizontal)
            
            Spacer()
            
            LeftFieldsView(fields: leftFields, exercise: viewModel.exercise, onEdit: onEdit, isEditable: isEditable)
            if let right = rightField {
                RightFieldView(field: right, exercise: viewModel.exercise, onEdit: onEdit, isEditable: isEditable)            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 4)
    }
}

struct AnalyticsSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: -24) {
            AppIconView(styled: StyledExerciseField(field: .action(.analyticsIcon)))
            
            TextView(styled: StyledExerciseField(field: .action(.analyticsText)))
                .offset(x: 10)
        }
    }
}

struct LeftFieldsView: View {
    let fields: [StyledExerciseField]
    let exercise: Exercise
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(fields) { styled in
                AppChipView(styled: styled, onTap: handleTap(for: styled))
                    .frame(width: 80)
            }
        }
    }
    
    private func handleTap(for styled: StyledExerciseField) -> (() -> Void)? {
        if !isEditable { return nil }
        
        if styled.data.field == .edit(.repsChip) || styled.data.field == .edit(.setsChip) {
            return { onEdit(exercise) }
        }
        return nil
    }
}

struct RightFieldView: View {
    let field: StyledExerciseField
    let exercise: Exercise
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    
    var body: some View {
        AppChipView(styled: field, onTap: isEditable && field.data.field == .edit(.weightChip) ? { onEdit(exercise) } : nil)
    }
}
