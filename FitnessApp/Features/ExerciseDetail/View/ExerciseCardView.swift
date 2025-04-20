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
            let config = ExerciseFieldConfig.config(for: .edit(.seatChip))
            
            HStack(alignment: .top) {
                Text(title)
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .accessibilityIdentifier(IDS.nameLabel)
                
                Spacer()
                
                Button(action: onSeatTap) {
                    AppChip(
                        text: seatText,
                        fontColor: AppStyle.Color.white,
                        backgroundColor: config.backgroundColor,
                        size: config.chipSize,
                        icon: config.icon
                    )
                    .scaleEffect(1.1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(IDS.seatLabel)
            }
        }
    }
    
    struct CardBottomSectionView: View {
        @ObservedObject var viewModel: ExerciseCardViewModel
        let currentReps: Int
        let onFieldTap: (InteractionField, String) -> Void
        
        var body: some View {
            let fields = viewModel.generateFieldData()
            let leftFields = fields.filter { ExerciseFieldConfig.config(for: $0.field).column == .left }
            let rightField = fields.first(where: { ExerciseFieldConfig.config(for: $0.field).column == .right })
            
            HStack(alignment: .center, spacing: 12) {
                AppChipExternalIcon(
                    iconConfig: ExerciseFieldConfig.config(for: .action(.analyticsIcon)),
                    chipText: L10n.analyticsChipText,
                )
                
                Spacer(minLength: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(leftFields, id: \.id) { field in
                        let config = ExerciseFieldConfig.config(for: field.field)
                        Button(action: {
                            onFieldTap(field.field, field.prefilledValue)
                        }) {
                            AppChip(
                                text: "\(field.value)\(config.textSuffix ?? "")",
                                fontColor: .white,
                                backgroundColor: config.backgroundColor,
                                size: config.chipSize,
                                icon: config.icon
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if let weightField = rightField {
                    let config = ExerciseFieldConfig.config(for: weightField.field)
                    Button(action: {
                        onFieldTap(weightField.field, weightField.prefilledValue)
                    }) {
                        AppChip(
                            text: "\(weightField.value)\(config.textSuffix ?? "")",
                            fontColor: .white,
                            backgroundColor: config.backgroundColor,
                            size: config.chipSize,
                            icon: config.icon
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(height: config.frameHeight)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
        }
    }
    
    struct AppChipExternalIcon: View {
        let iconConfig: ExerciseFieldStyle
        let chipText: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: -24) {
                iconConfig.icon?.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .offset(x: 12, y: -12)
                AppChip(
                    text: chipText,
                    fontColor: AppStyle.Color.purpleDark,
                    backgroundColor: iconConfig.backgroundColor,
                    icon: nil
                )
            }
        }
    }
}
