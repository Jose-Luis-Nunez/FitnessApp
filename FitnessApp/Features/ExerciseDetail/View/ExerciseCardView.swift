import SwiftUI

private struct IDS {
    static let nameLabel = "id_label_exercise_name"
    static let seatLabel = "id_label_exercise_seat"
    static let weightButton = "id_button_weight"
    static let setsButton = "id_button_sets"
    static let repsButton = "id_button_reps"
    static let progressLabel = "id_label_progress"
}

struct ExerciseCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @State private var editMode: ExerciseCardViewModel.EditMode = .none
    @State private var editValue = ""
    @State private var localIsCompleted: Bool = false
    
    private var isEditing: Binding<Bool> {
        Binding(
            get: { editMode != .none },
            set: { if !$0 { editMode = .none } }
        )
    }
    
    var body: some View {
        FitnessCard(style: viewModel.isCompleted ? .completed : .primary) {
            VStack(spacing: AppStyle.Layout.Card.contentPadding.top) {
                CardHeaderView(
                    name: viewModel.name,
                    seatText: viewModel.seatDisplayText,
                    onSeatTap: { showEdit(mode: .seat) }
                )

                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal, 4)

                CardContentView(
                    viewModel: viewModel,
                    onSetsTap: { showEdit(mode: .sets) },
                    onRepsTap: { showEdit(mode: .reps) },
                    onWeightTap: { showEdit(mode: .weight) }
                )
            }
            .padding(AppStyle.Layout.Card.contentPadding)
        }
        .id("\(viewModel.isCompleted)_\(localIsCompleted)")
        .onChange(of: viewModel.isCompleted) { newValue in
            localIsCompleted = newValue
        }
        .onAppear {
            localIsCompleted = viewModel.isCompleted
        }
        .sheet(isPresented: isEditing) {
            EditSheet(
                title: editMode.title,
                placeholder: editMode.placeholder,
                value: $editValue,
                keyboardType: editMode.requiresNumericKeyboard ? .numberPad : .default,
                onSave: {
                    switch editMode {
                    case .seat:
                        viewModel.updateSeat(editValue)
                    case .weight:
                        if let weight = Int(editValue) {
                            viewModel.updateWeight(weight)
                        }
                    case .sets:
                        if let sets = Int(editValue) {
                            viewModel.updateSets(sets)
                        }
                    case .reps:
                        if let reps = Int(editValue) {
                            viewModel.updateReps(reps)
                        }
                    case .none:
                        break
                    }
                }
            )
        }
    }
    
    private func showEdit(mode: ExerciseCardViewModel.EditMode) {
        editMode = mode
        editValue = viewModel.getInitialValue(for: mode)
    }
}

private struct CardHeaderView: View {
    let name: String
    let seatText: String
    let onSeatTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            Text(name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .accessibilityIdentifier(IDS.nameLabel)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onSeatTap) {
                FitnessChip(
                    seatText,
                    icon: Image("iconSeatSettings"),
                    style: .custom(background: Color(hex: "#2A1B66"), foreground: .white)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: AppStyle.Layout.Card.Content.steigendWidth)
            .accessibilityIdentifier(IDS.seatLabel)
            .accessibilityLabel(seatText)
            .accessibilityHint("Tippen um Sitzeinstellung zu ändern")
        }
    }
}

private struct CardContentView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onSetsTap: () -> Void
    let onRepsTap: () -> Void
    let onWeightTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: AppStyle.Layout.Card.Content.spacing) {
            ProgressSection()
            
            Spacer()  // Flexible space that won't force content outside bounds
            
            HStack(spacing: 8) {  // Group sets/reps and weight together
                SetsRepsSection(
                    setsText: viewModel.setsDisplayText,
                    repsText: viewModel.repsDisplayText,
                    setsAccessibilityLabel: viewModel.setsAccessibilityLabel,
                    repsAccessibilityLabel: viewModel.repsAccessibilityLabel,
                    onSetsTap: onSetsTap,
                    onRepsTap: onRepsTap
                )
                
                WeightSection(
                    text: viewModel.weightDisplayText,
                    accessibilityLabel: viewModel.weightAccessibilityLabel,
                    onTap: onWeightTap
                )
            }
        }
        .padding(.horizontal, 8)  // Add some horizontal padding to maintain margins
    }
}

private struct ProgressSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: -8) {
            Image("iconActivityIncrease")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            
            FitnessChip(
                L10n.ExerciseCard.steigend,
                style: .custom(background: Color(hex: "#2A1B66"), foreground: .white),
                size: .mediumWide
            )
        }
        .frame(width: AppStyle.Layout.Card.Content.steigendWidth)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(IDS.progressLabel)
        .accessibilityLabel("Fortschritt: Steigend")
    }
}

private struct SetsRepsSection: View {
    let setsText: String
    let repsText: String
    let setsAccessibilityLabel: String
    let repsAccessibilityLabel: String
    let onSetsTap: () -> Void
    let onRepsTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSetsTap) {
                FitnessChip(
                    setsText,
                    icon: Image(systemName: "bolt.fill"),
                    style: .custom(background: Color(hex: "#2A1B66"), foreground: .white),
                    iconColor: .yellow,
                    size: .medium
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier(IDS.setsButton)
            .accessibilityLabel(setsAccessibilityLabel)
            .accessibilityHint("Tippen um Anzahl Sätze zu ändern")

            Button(action: onRepsTap) {
                FitnessChip(
                    repsText,
                    icon: Image(systemName: "arrow.triangle.2.circlepath"),
                    style: .custom(background: Color(hex: "#2A1B66"), foreground: .white),
                    iconColor: .white,
                    size: .medium
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier(IDS.repsButton)
            .accessibilityLabel(repsAccessibilityLabel)
            .accessibilityHint("Tippen um Anzahl Wiederholungen zu ändern")
        }
        .frame(width: AppStyle.Layout.Card.Content.setsRepsWidth)
    }
}

private struct WeightSection: View {
    let text: String
    let accessibilityLabel: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            FitnessChip(
                text,
                style: .custom(background: Color(hex: "#2A1B66"), foreground: .white),
                size: .large
            )
            .frame(
                width: AppStyle.Layout.Card.Content.weightWidth,
                height: AppStyle.Layout.Card.Content.weightHeight
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(IDS.weightButton)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tippen um Gewicht zu ändern")
    }
}

private struct EditSheet: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    let keyboardType: UIKeyboardType
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(placeholder, text: $value)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle(title)
            .navigationBarItems(
                leading: Button(L10n.ExerciseCard.cancel) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(L10n.ExerciseCard.save) {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
