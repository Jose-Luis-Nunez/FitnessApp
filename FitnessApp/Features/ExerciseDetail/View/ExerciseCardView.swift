import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

enum EditField: Identifiable {
    case seat, weight, sets, reps

    var id: String {
        switch self {
        case .seat: return "seat"
        case .weight: return "weight"
        case .sets: return "sets"
        case .reps: return "reps"
        }
    }

    var title: String {
        switch self {
        case .seat: return "Sitzeinstellung ändern"
        case .weight: return "Gewicht ändern"
        case .sets: return "Sätze ändern"
        case .reps: return "Wiederholungen ändern"
        }
    }

    var placeholder: String {
        switch self {
        case .seat: return "Neue Einstellung"
        case .weight: return "Neues Gewicht"
        case .sets: return "Neue Anzahl"
        case .reps: return "Neue Anzahl"
        }
    }
}

struct ExerciseCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @State private var activeEditField: EditField?
    @State private var inputValue = ""

    var body: some View {
        VStack(spacing: 8) {
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: seatDisplayText,
                onSeatTap: {
                    inputValue = viewModel.exercise.seatSetting ?? ""
                    activeEditField = .seat
                }
            )

            Divider().background(AppStyle.Color.purpleGrey).padding(.horizontal, 4)

            CardBottomSectionView(
                weight: viewModel.exercise.weight,
                reps: viewModel.exercise.reps,
                currentReps: viewModel.exercise.currentReps,
                sets: viewModel.exercise.sets,
                onWeightTap: {
                    inputValue = "\(viewModel.exercise.weight)"
                    activeEditField = .weight
                },
                onSetsTap: {
                    inputValue = "\(viewModel.exercise.sets)"
                    activeEditField = .sets
                },
                onRepsTap: {
                    inputValue = "\(viewModel.exercise.reps)"
                    activeEditField = .reps
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
        .sheet(item: $activeEditField) { field in
               EditValueSheet(
                   title: field.title,
                   placeholder: field.placeholder,
                   input: $inputValue,
                   onSave: {
                       switch field {
                       case .seat:
                           viewModel.updateSeat(inputValue)
                       case .weight:
                           if let value = Int(inputValue) {
                               viewModel.updateWeight(value)
                           }
                       case .sets:
                           if let value = Int(inputValue) {
                               viewModel.updateSets(value)
                           }
                       case .reps:
                           if let value = Int(inputValue) {
                               viewModel.updateReps(value)
                           }
                       }
                       activeEditField = nil
                   },
                   onCancel: {
                       activeEditField = nil
                   },
                   keyboardType: .numberPad,
                   saveDisabled: field == .seat ? inputValue.isEmpty : Int(inputValue) == nil
               )
           }
    }

    private var seatDisplayText: String {
        if let seat = viewModel.exercise.seatSetting, !seat.isEmpty {
            return "\(seat)"
        } else {
            return L10n.seatChipDefaultvalue
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
                .font(AppStyle.Font.headlineLarge)
                .foregroundColor(AppStyle.Color.white)
                .accessibilityIdentifier(IDS.nameLabel)

            Spacer()

            Button(action: onSeatTap) {
                AppChip(
                    text: seatText,
                    icon: Image("iconSeatSettings"),
                    backgroundColor: AppStyle.Color.purple,
                    fontColor: AppStyle.Color.white
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(IDS.seatLabel)
        }
    }
}

struct CardBottomSectionView: View {
    let weight: Int
    let reps: Int
    let currentReps: Int
    let sets: Int
    let onWeightTap: () -> Void
    let onSetsTap: () -> Void
    let onRepsTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconTextColumnView(
                icon: Image("iconActivityIncrease"),
                chipText: "STEIGEND",
                chipBackground: AppStyle.Color.purpleLight
            )

            Spacer(minLength: 4)

            ChipColumnView(
                reps: reps,
                currentReps: currentReps,
                sets: sets,
                onSetsTap: onSetsTap,
                onRepsTap: onRepsTap
            )

            Button(action: onWeightTap) {
                AppChip(
                    text: "\(weight) kg",
                    icon: nil,
                    backgroundColor: AppStyle.Color.purpleGrey,
                    fontColor: AppStyle.Color.white,
                    size: .large
                )
            }
            .buttonStyle(.plain)
            .frame(height: AppStyle.Dimensions.chipHeight * 2 + 42)
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
}

struct IconTextColumnView: View {
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
                icon: nil,
                backgroundColor: chipBackground,
                fontColor: AppStyle.Color.purpleDark
            )
        }
    }
}

struct ChipColumnView: View {
    let reps: Int
    let currentReps: Int
    let sets: Int
    let onSetsTap: () -> Void
    let onRepsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onSetsTap) {
                AppChip(
                    text: "\(sets)x",
                    icon: Image(systemName: "bolt.fill"),
                    backgroundColor: AppStyle.Color.purpleGrey,
                    fontColor: AppStyle.Color.white
                )
            }
            .buttonStyle(.plain)

            Button(action: onRepsTap) {
                AppChip(
                    text: "\(reps)",
                    icon: Image(systemName: "arrow.triangle.2.circlepath"),
                    backgroundColor: AppStyle.Color.purpleGrey,
                    fontColor: AppStyle.Color.white
                )
            }
            .buttonStyle(.plain)
        }
    }
}
