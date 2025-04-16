import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
}

struct ExerciseCardView: View {
    @StateObject var viewModel: ExerciseCardViewModel
    @State private var isEditingSeat = false
    @State private var isEditingWeight = false
    @State private var isEditingSets = false
    @State private var isEditingReps = false
    @State private var isEditingCurrentReps = false
    @State private var seatInput = ""
    @State private var weightInput = ""
    @State private var setsInput = ""
    @State private var repsInput = ""
    @State private var currentRepsInput = ""

    var body: some View {
        VStack(spacing: 8) {
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: seatDisplayText,
                onSeatTap: {
                    seatInput = viewModel.exercise.seatSetting ?? ""
                    isEditingSeat = true
                }
            )

            Divider().background(AppStyle.Color.transparent).padding(.horizontal, 4)

            CardBottomSectionView(
                weight: viewModel.exercise.weight,
                reps: viewModel.exercise.reps,
                currentReps: viewModel.exercise.currentReps,
                sets: viewModel.exercise.sets,
                onWeightTap: {
                    weightInput = "\(viewModel.exercise.weight)"
                    isEditingWeight = true
                },
                onSetsTap: {
                    setsInput = "\(viewModel.exercise.sets)"
                    isEditingSets = true
                },
                onRepsTap: {
                    repsInput = "\(viewModel.exercise.reps)"
                    isEditingReps = true
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
        .sheet(isPresented: $isEditingSeat) {
            seatEditSheet
        }
        .sheet(isPresented: $isEditingWeight) {
            weightEditSheet
        }
        .sheet(isPresented: $isEditingSets) {
            setsEditSheet
        }
        .sheet(isPresented: $isEditingReps) {
            repsEditSheet
        }
        .sheet(isPresented: $isEditingCurrentReps) {
            currentRepsEditSheet
        }
    }

    private var seatDisplayText: String {
        if let seat = viewModel.exercise.seatSetting, !seat.isEmpty {
            return "\(seat)"
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

    private var weightEditSheet: some View {
        VStack(spacing: 20) {
            Text("Gewicht ändern")
                .font(.headline)

            TextField("Neues Gewicht", text: $weightInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Speichern") {
                if let newWeight = Int(weightInput) {
                    viewModel.updateWeight(newWeight)
                }
                isEditingWeight = false
            }
            .buttonStyle(.borderedProminent)

            Button("Abbrechen") {
                isEditingWeight = false
            }
            .foregroundColor(.red)
        }
        .padding()
    }

    private var setsEditSheet: some View {
        VStack(spacing: 20) {
            Text("Sätze ändern")
                .font(.headline)

            TextField("Neue Anzahl", text: $setsInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Speichern") {
                if let newSets = Int(setsInput) {
                    viewModel.updateSets(newSets)
                }
                isEditingSets = false
            }
            .buttonStyle(.borderedProminent)

            Button("Abbrechen") {
                isEditingSets = false
            }
            .foregroundColor(.red)
        }
        .padding()
    }

    private var repsEditSheet: some View {
        VStack(spacing: 20) {
            Text("Wiederholungen ändern")
                .font(.headline)

            TextField("Neue Anzahl", text: $repsInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Speichern") {
                if let newReps = Int(repsInput) {
                    viewModel.updateReps(newReps)
                }
                isEditingReps = false
            }
            .buttonStyle(.borderedProminent)

            Button("Abbrechen") {
                isEditingReps = false
            }
            .foregroundColor(.red)
        }
        .padding()
    }

    private var currentRepsEditSheet: some View {
        VStack(spacing: 20) {
            Text("Wiederholungen anpassen")
                .font(.headline)

            TextField("Neue Anzahl", text: $currentRepsInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Speichern") {
                if let newReps = Int(currentRepsInput),
                   (newReps < viewModel.exercise.reps) {
                    viewModel.updateRepsForCurrentSet(newReps)
                }
                isEditingCurrentReps = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(Int(currentRepsInput).map { $0 >= viewModel.exercise.reps } ?? true)

            Button("Abbrechen") {
                isEditingCurrentReps = false
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
                    backgroundColor: AppStyle.Color.transparent,
                    fontColor: AppStyle.Color.white
                )
            }
            .buttonStyle(.plain)

            Button(action: onRepsTap) {
                AppChip(
                    text: "\(currentReps)",
                    icon: Image(systemName: "arrow.triangle.2.circlepath"),
                    backgroundColor: AppStyle.Color.transparent,
                    fontColor: AppStyle.Color.white
                )
            }
            .buttonStyle(.plain)
        }
    }
}
