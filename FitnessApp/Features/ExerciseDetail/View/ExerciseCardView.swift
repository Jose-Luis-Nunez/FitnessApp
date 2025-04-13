import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

struct ExerciseCardView: View {
    @StateObject var viewModel: ExerciseCardViewModel
    @State private var isEditingSeat = false
    @State private var seatInput = ""

    var body: some View {
        VStack(spacing: 12) {
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: seatDisplayText,
                onSeatTap: {
                    seatInput = viewModel.exercise.seatSetting ?? ""
                    isEditingSeat = true
                }
            )

            Divider().background(Color.white.opacity(0.4)).padding(.horizontal, 4)

            CardBottomSectionView(
                weight: viewModel.exercise.weight,
                reps: viewModel.exercise.reps,
                sets: viewModel.exercise.sets
            )
        }
        .padding()
        .background(AppStyle.Color.cardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
        .sheet(isPresented: $isEditingSeat) {
            seatEditSheet
        }
    }

    private var seatDisplayText: String {
        if let seat = viewModel.exercise.seatSetting, !seat.isEmpty {
            return "\(L10n.seat): \(seat)"
        } else {
            return L10n.seatOptional
        }
    }

    private var seatEditSheet: some View {
        VStack(spacing: 20) {
            Text("Sitzeinstellung ändern")
                .font(.headline)

            TextField("Neue Einstellung", text: $seatInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Speichern") {
                viewModel.updateSeat(seatInput)
                isEditingSeat = false
            }
            .buttonStyle(.borderedProminent)

            Button("Abbrechen") {
                isEditingSeat = false
            }
            .foregroundColor(.red)
        }
        .padding()
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
                .foregroundColor(.white)
                .accessibilityIdentifier(IDS.nameLabel)

            Spacer()

            Button(action: onSeatTap) {
                AppChip(
                    text: seatText,
                    icon: Image("iconSeatSettings"),
                    backgroundColor: AppStyle.Color.seatChip,
                    foregroundColor: .white
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
    let sets: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            IconTextColumnView(
                icon: Image("iconActivityIncrease"),
                chipText: "STEIGEND",
                chipBackground: AppStyle.Color.chipPurple
            )

            ChipColumnView(reps: reps, sets: sets)

            Spacer()

            WeightDisplayView(weight: weight)
        }
    }
}

struct IconTextColumnView: View {
    let icon: Image
    let chipText: String
    let chipBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            AppChip(
                text: chipText,
                icon: nil,
                backgroundColor: chipBackground,
                foregroundColor: .white
            )
        }
    }
}

struct ChipColumnView: View {
    let reps: Int
    let sets: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AppChip(
                text: "\(sets)x",
                icon: Image(systemName: "bolt.fill"),
                backgroundColor: .white.opacity(0.2),
                foregroundColor: .white
            )
            AppChip(
                text: "\(reps)",
                icon: Image(systemName: "arrow.triangle.2.circlepath"),
                backgroundColor: .white.opacity(0.2),
                foregroundColor: .white
            )
        }
    }
}

struct WeightDisplayView: View {
    let weight: Int

    var body: some View {
        Text("\(weight) kg")
            .font(AppStyle.Font.metricValue)
            .foregroundColor(.white)
            .padding(8)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
