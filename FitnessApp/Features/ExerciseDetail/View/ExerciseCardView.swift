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
                seatText: seatDisplayText,
                onSeatTap: {
                    inputValue = viewModel.exercise.seatSetting ?? ""
                    activeSheet = .edit(.seatChip)
                }
            )
            
            Divider().background(AppStyle.Color.purpleGrey).padding(.horizontal, 4)
            
            CardBottomSectionView(
                viewModel: viewModel,
                currentReps: viewModel.exercise.currentReps,
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
        .background(viewModel.exercise.isCompleted ? AppStyle.Color.purpleLight : AppStyle.Color.purpleDark)
        .cornerRadius(AppStyle.CornerRadius.card)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
        .sheet(item: $activeSheet) { sheet in
            editSheet(for: sheet)
        }
    }
    
    private var seatDisplayText: String {
        if let seat = viewModel.exercise.seatSetting, !seat.isEmpty {
            return "\(seat)"
        } else {
            return L10n.seatChipDefaultvalue
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
            let seatChip = ExerciseCardConfig.config(for: .edit(.seatChip)).display
            let exerciseCardTitleText = ExerciseCardConfig.config(for: .action(.exerciseCardTitleText)).display
            
            HStack(alignment: .top) {
                if case let .text(text) = exerciseCardTitleText {
                    Text(title)
                        .font(text.textFontSize)
                        .foregroundColor(text.textColor)
                        .accessibilityIdentifier(IDS.nameLabel)
                }
                
                Spacer()
                
                if case let .chip(style) = seatChip {
                    Button(action: onSeatTap) {
                        AppChip(
                            text: seatText,
                            fontColor: style.labelColor,
                            backgroundColor: style.backgroundColor,
                            size: style.size,
                            icon: style.icon
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
                    
                    let analyticsIcon = ExerciseCardConfig.config(for: .action(.analyticsIcon)).display
                    let analyticsText = ExerciseCardConfig.config(for: .action(.analyticsText)).display
                    
                    if case let .icon(analyticsIcon) = analyticsIcon {
                        analyticsIcon.icon.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .offset(x: 12, y: -12)
                    }
                    
                    if case let .text(text) = analyticsText {
                        Text(text.text)
                            .font(text.textFontSize)
                            .foregroundColor(text.textColor)
                    }
                }
                
                Spacer(minLength: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(leftFields) { styled in
                        if case let .chip(style) = styled.style.display {
                            Button(action: {
                                onFieldTap(styled.data.field, styled.data.prefilledValue)
                            }) {
                                AppChip(
                                    text: "\(styled.data.value)\(style.textSuffix ?? "")",
                                    fontColor: style.labelColor,
                                    backgroundColor: style.backgroundColor,
                                    size: style.size,
                                    icon: style.icon
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if let right = rightField, case let .chip(style) = right.style.display {
                    Button(action: {
                        onFieldTap(right.data.field, right.data.prefilledValue)
                    }) {
                        AppChip(
                            text: "\(right.data.value)\(style.textSuffix ?? "")",
                            fontColor: style.labelColor,
                            backgroundColor: style.backgroundColor,
                            size: style.size,
                            icon: style.icon
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(height: right.style.frameHeight)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
        }
    }
}
