import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

enum EditField: Identifiable {
    case seat, weight, sets, reps
    var id: String {
        String(describing: self)
    }
}

struct ExerciseCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    
    @State private var activeSheet: EditField?
    @State private var inputValue = ""
    
    var body: some View {
        VStack(spacing: 8) {
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: seatDisplayText,
                onSeatTap: {
                    inputValue = viewModel.exercise.seatSetting ?? ""
                    activeSheet = .seat
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
    private func editSheet(for field: EditField) -> some View {
        switch field {
        case .seat:
            EditValueSheet(
                title: "Sitzeinstellung ändern",
                placeholder: "Neue Einstellung",
                input: $inputValue,
                onSave: {
                    viewModel.updateSeat(inputValue)
                    activeSheet = nil
                },
                onCancel: {
                    activeSheet = nil
                },
                keyboardType: .numberPad,
                saveDisabled: inputValue.isEmpty
            )
            
        case .weight:
            EditValueSheet(
                title: "Gewicht ändern",
                placeholder: "Neues Gewicht",
                input: $inputValue,
                onSave: {
                    if let val = Int(inputValue) {
                        viewModel.updateWeight(val)
                    }
                    activeSheet = nil
                },
                onCancel: {
                    activeSheet = nil
                },
                keyboardType: .numberPad,
                saveDisabled: Int(inputValue) == nil
            )
            
        case .sets:
            EditValueSheet(
                title: "Sätze ändern",
                placeholder: "Neue Anzahl",
                input: $inputValue,
                onSave: {
                    if let val = Int(inputValue) {
                        viewModel.updateSets(val)
                    }
                    activeSheet = nil
                },
                onCancel: {
                    activeSheet = nil
                },
                keyboardType: .numberPad,
                saveDisabled: Int(inputValue) == nil
            )
            
        case .reps:
            EditValueSheet(
                title: "Wiederholungen ändern",
                placeholder: "Neue Anzahl",
                input: $inputValue,
                onSave: {
                    if let val = Int(inputValue) {
                        viewModel.updateReps(val)
                    }
                    activeSheet = nil
                },
                onCancel: {
                    activeSheet = nil
                },
                keyboardType: .numberPad,
                saveDisabled: Int(inputValue) == nil
            )
        }
    }
}

struct CardTopSectionView: View {
    let title: String
    let seatText: String
    let onSeatTap: () -> Void
    
    var body: some View {
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
                    backgroundColor: AppStyle.Color.purple,
                    icon: ChipIcon(image: Image("iconSeatSettings"), color: AppStyle.Color.white)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(IDS.seatLabel)
        }
    }
}

struct CardBottomSectionView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let currentReps: Int
    let onFieldTap: (EditField, String) -> Void
    
    var body: some View {
        let fields = viewModel.generateFieldTypes()
        let leftFields = fields.filter { $0.column == .left }
        let rightField = fields.first(where: { $0.column == .right })
        
        HStack(alignment: .center, spacing: 12) {
            AppChipExternalIcon(
                icon: Image("iconActivityIncrease"),
                chipText: "STEIGEND",
                chipBackground: AppStyle.Color.purpleLight
            )
            
            Spacer(minLength: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(leftFields) { field in
                    Button(action: {
                        onFieldTap(field.editField, field.prefilledValue)
                    }) {
                        AppChip(
                            text: field.valueText,
                            fontColor: AppStyle.Color.white,
                            backgroundColor: AppStyle.Color.purpleGrey,
                            icon: ExerciseFieldType.icon(for: field.editField)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let weightField = rightField {
                Button(action: {
                    onFieldTap(weightField.editField, weightField.prefilledValue)
                }) {
                    AppChip(
                        text: weightField.valueText,
                        fontColor: AppStyle.Color.white,
                        backgroundColor: AppStyle.Color.purpleGrey,
                        size: .large,
                        icon: nil
                    )
                }
                .buttonStyle(.plain)
                .frame(height: weightField.frameHeight)
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
}

struct AppChipExternalIcon: View {
    let icon: Image
    let chipText: String
    let chipBackground: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: -24) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .offset(x: 12, y: -12)
            AppChip(
                text: chipText,
                fontColor: AppStyle.Color.purpleDark,
                backgroundColor: chipBackground,
                icon: nil
            )
        }
    }
}
