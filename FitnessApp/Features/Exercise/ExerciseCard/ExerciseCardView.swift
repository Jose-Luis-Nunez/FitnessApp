import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

struct ExerciseCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onStart: ((Exercise) -> Void)?
    let onReset: ((Exercise) -> Void)?
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
                onStart: onStart,
                onReset: onReset,
                isActiveSetVisible: isActiveSetVisible

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
        .background(viewModel.exercise.isCompleted ? AppStyle.Color.exerciseCardDoneBackGround : AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
    }
}

struct CardTopSectionView: View {
    let title: String
    let seatText: String
    let onEdit: (Exercise) -> Void
    let exercise: Exercise
    let isEditable: Bool
    let onStart: ((Exercise) -> Void)?
    let onReset: ((Exercise) -> Void)?
    let isActiveSetVisible: Bool

    
    var body: some View {
        HStack(alignment: .top) {
            TextView(
                styled: StyledExerciseField(field: .action(.exerciseCardTitleText)),
                content: title
            )
            .frame(maxWidth: 400, maxHeight: 20, alignment: .leading)
            .lineLimit(1)
            .allowsTightening(true)
            .minimumScaleFactor(0.7)
            .accessibilityIdentifier(IDS.nameLabel)
            .onTapGesture {
                if isEditable {
                    onEdit(exercise)
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                if isEditable, let onReset = onReset, exercise.isCompleted {
                    Button(action: {
                        onReset(exercise)
                    }) {
                        Image(systemName: "eject.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppStyle.Color.black)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("id_button_reset_exercise")
                }
                
                AppChipView(
                    styled: StyledExerciseField(field: .edit(.seatChip)),
                    content: seatText,
                    onTap: isEditable ? { onEdit(exercise) } : nil
                )
                .frame(width: 60)
                .accessibilityIdentifier(IDS.seatLabel)
            }
            
            if let onStart = onStart, !exercise.isCompleted, !isActiveSetVisible {
                Button(action: {
                    onStart(exercise)
                }) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppStyle.Color.black)
                        .cornerRadius(12)
                }
                .accessibilityIdentifier("id_button_start_exercise")
                .buttonStyle(.plain)
            }
        }
    }
}



struct CardBottomSectionView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let currentReps: Int
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    var body: some View {
        let styledFields = viewModel.generateStyledFieldData()
        let leftFields = styledFields.filter { $0.style.column == .left }
        let rightField = styledFields.first(where: { $0.style.column == .right })
        
        HStack(alignment: .center, spacing: 8) {
            AnalyticsSectionView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
            
            Spacer()
            
            LeftFieldsView(
                fields: leftFields,
                exercise: viewModel.exercise,
                onEdit: onEdit,
                isEditable: isEditable
            )
                        
            if let right = rightField {
                RightFieldView(
                    field: right,
                    exercise: viewModel.exercise,
                    onEdit: onEdit,
                    isEditable: isEditable
                )
            }
        }
        .padding(.vertical, 4)
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
