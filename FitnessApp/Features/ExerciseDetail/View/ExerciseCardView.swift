import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

struct ExerciseCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    
    @State private var activeSheet: InteractionField?
    @State private var inputValue = ""
    
    var body: some View {
        VStack(spacing: 8) {
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: viewModel.displaySeatText,
                onSeatTap: {
                    inputValue = viewModel.exercise.seatSetting ?? ""
                    activeSheet = .edit(.seatChip)
                }
            )
            
            Divider().background(AppStyle.Color.purpleGrey).padding(.horizontal, 4)
            
            CardBottomSectionView(
                viewModel: viewModel,
                currentReps: viewModel.exercise.reps,
                onFieldTap: { field, value in
                    inputValue = value
                    activeSheet = field
                }
            )
            .scaleEffect(1.1)
            .padding(.top, 2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(viewModel.exercise.isCompleted ? AppStyle.Color.exerciseCardDoneBackGround : AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
        .sheet(item: $activeSheet) { sheet in
            editSheet(for: sheet)
        }
    }
    
    @ViewBuilder
    private func editSheet(for field: InteractionField) -> some View {
        if case let .edit(type) = field {
            let metadata = type.metadata
            EditValueSheet(
                title: metadata.title,
                placeholder: metadata.placeholder,
                input: $inputValue,
                onSave: {
                    metadata.save(inputValue, viewModel)
                    activeSheet = nil
                },
                onCancel: {
                    activeSheet = nil
                },
                keyboardType: metadata.keyboardType,
                saveDisabled: !metadata.validate(inputValue)
            )
        } else {
            EmptyView()
        }
    }
    
    struct CardTopSectionView: View {
        let title: String
        let seatText: String
        let onSeatTap: () -> Void
        
        var body: some View {
            HStack(alignment: .top) {
                
                TextView(
                    styled: StyledExerciseField(field: .action(.exerciseCardTitleText)),
                    content: title
                ).accessibilityIdentifier(IDS.nameLabel)
                
                Spacer()
                
                Button(action: onSeatTap) {
                    AppChipView(
                        styled: StyledExerciseField(field: .edit(.seatChip)),
                        content: seatText
                    )
                    .scaleEffect(1.1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(IDS.seatLabel)
            }
        }
    }
}

struct CardBottomSectionView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let currentReps: Int
    let onFieldTap: (InteractionField, String) -> Void
    
    var body: some View {
        let styledFields = viewModel.generateStyledFieldData()
        let leftFields = styledFields.filter { $0.style.column == .left }
        let rightField = styledFields.first(where: { $0.style.column == .right })
        
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: -24) {
                AppIconView(styled: StyledExerciseField(field: .action(.analyticsIcon)))
                
                TextView(styled: StyledExerciseField(field: .action(.analyticsText)))
            }
            
            Spacer(minLength: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(leftFields) { styled in
                    Button(action: {
                        onFieldTap(styled.data.field, styled.data.prefilledValue)
                    }) {
                        AppChipView(styled: styled)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let right = rightField {
                Button(action: {
                    onFieldTap(right.data.field, right.data.prefilledValue)
                }) {
                    AppChipView(styled: right)
                }
                .buttonStyle(.plain)
                .frame(height: right.style.frameHeight)
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
}
