import SwiftUI

private struct IDS {
    static let groupTitle = "id_title_group"
    static let nameField = "id_field_name"
    static let weightField = "id_field_weight"
    static let repsField = "id_field_reps"
    static let setsField = "id_field_sets"
    static let seatField = "id_field_seat"
    static let saveButton = "id_button_save"
    static let cancelButton = "id_button_cancel"
    static let addExerciseButton = "id_button_add_exercise"
}

struct MuscleCategoryView: View {
    enum RepsEditMode {
        case less, more
    }

    let group: MuscleCategoryGroup
    @StateObject private var viewModel: MuscleCategoryViewModel
    @State private var showForm = false
    @State private var isEditingCurrentReps = false
    @State private var currentRepsInput = ""
    @State private var currentRepsEditMode: RepsEditMode = .less
    @State private var name = ""
    @State private var weight = ""
    @State private var reps = ""
    @State private var sets = ""
    @State private var seat = ""
    @State private var showResetConfirmation = false

    init(group: MuscleCategoryGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: MuscleCategoryViewModel(group: group))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Text(group.rawValue)
                    .font(AppStyle.Font.title)
                    .padding([.top, .horizontal], AppStyle.Padding.horizontal)
                    .accessibilityIdentifier(IDS.groupTitle)

                List {
                    exerciseListSection

                    if showForm {
                        exerciseFormSection
                    }
                }
                .listStyle(.plain)
            }
            .navigationBarTitle(group.rawValue, displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                withAnimation { showForm.toggle() }
            }) {
                Image(systemName: showForm ? "minus" : "plus")
            }.accessibilityIdentifier(IDS.addExerciseButton))

            // FABs at the bottom
            if let activeExercise = viewModel.exercises.first(where: { !$0.isCompleted }) {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        if viewModel.isSetInProgress {
                            // Less Button
                            Button(action: {
                                currentRepsEditMode = .less
                                isEditingCurrentReps = true
                            }) {
                                Text("Less")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(AppStyle.Color.purpleDark)
                                    .clipShape(Capsule())
                            }
                            .padding(.trailing, 8)

                            // Done Button
                            Button(action: {
                                viewModel.completeCurrentSet()
                            }) {
                                Text("Done!")
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppStyle.Color.purpleDark)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(AppStyle.Color.white)
                                    .clipShape(Capsule())
                            }

                            // More Button
                            Button(action: {
                                currentRepsEditMode = .more
                                isEditingCurrentReps = true
                            }) {
                                Text("More")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(AppStyle.Color.purpleDark)
                                    .clipShape(Capsule())
                            }
                            .padding(.leading, 8)
                        } else {
                            // Start Button
                            Button(action: {
                                viewModel.startSet(for: activeExercise)
                            }) {
                                Text(viewModel.startButtonTitle)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(AppStyle.Color.purpleDark)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    .background(
                        Rectangle()
                            .fill(Color.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
                    )
                }
            } else {
                // Reset Button when all exercises are completed
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showResetConfirmation = true
                        }) {
                            Text("Reset Progress")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(AppStyle.Color.purpleDark)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    .background(
                        Rectangle()
                            .fill(Color.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
                    )
                }
            }
        }
        .sheet(isPresented: $isEditingCurrentReps) {
            currentRepsEditSheet
        }
        .alert(isPresented: $showResetConfirmation) {
            Alert(
                title: Text("Reset Progress"),
                message: Text("Do you want to reset all exercise progress? This will allow you to start the sets again."),
                primaryButton: .destructive(Text("Reset")) {
                    viewModel.resetProgress()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var currentRepsEditSheet: some View {
        NavigationView {
            Form {
                Section(header: Text(currentRepsEditMode == .less ? "Weniger Wiederholungen" : "Mehr Wiederholungen")) {
                    TextField("Neue Anzahl", text: $currentRepsInput)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Wiederholungen anpassen")
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    isEditingCurrentReps = false
                    currentRepsInput = ""
                },
                trailing: Button("Speichern") {
                    if let newReps = Int(currentRepsInput),
                       let currentExercise = viewModel.currentExercise {
                        switch currentRepsEditMode {
                        case .less:
                            if newReps < currentExercise.reps {
                                viewModel.updateCurrentReps(newReps)
                                viewModel.completeCurrentSet()
                            }
                        case .more:
                            if newReps > currentExercise.reps {
                                viewModel.updateCurrentReps(newReps)
                                viewModel.completeCurrentSet()
                            }
                        }
                    }
                    isEditingCurrentReps = false
                    currentRepsInput = ""
                }
                .disabled(Int(currentRepsInput).map { reps in
                    guard let currentExercise = viewModel.currentExercise else { return true }
                    switch currentRepsEditMode {
                    case .less: return reps >= currentExercise.reps
                    case .more: return reps <= currentExercise.reps
                    }
                } ?? true)
            )
        }
    }

    private var exerciseListSection: some View {
        Group {
            // Active exercises (not completed) at the top
            ForEach(viewModel.exercises.filter { !$0.isCompleted }) { exercise in
                ExerciseCardView(
                    viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                        viewModel.updateExercise(updated)
                    }
                )
                .padding(.vertical, 4)
                .transition(.move(edge: .top))
            }
            
            // Completed exercises at the bottom
            ForEach(viewModel.exercises.filter { $0.isCompleted }) { exercise in
                ExerciseCardView(
                    viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                        viewModel.updateExercise(updated)
                    }
                )
                .padding(.vertical, 4)
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut, value: viewModel.exercises.map { $0.isCompleted })
    }

    private var exerciseFormSection: some View {
        Section(header: Text(L10n.newExercise)) {
            TextField(L10n.name, text: $name)
                .accessibilityIdentifier(IDS.nameField)
                .keyboardType(.default)

            TextField(L10n.weightKg, text: $weight)
                .accessibilityIdentifier(IDS.weightField)
                .keyboardType(.decimalPad)

            TextField(L10n.repetitions, text: $reps)
                .accessibilityIdentifier(IDS.repsField)
                .keyboardType(.numberPad)

            TextField(L10n.sets, text: $sets)
                .accessibilityIdentifier(IDS.setsField)
                .keyboardType(.numberPad)

            TextField(L10n.seatOptional, text: $seat)
                .accessibilityIdentifier(IDS.seatField)
                .keyboardType(.numberPad)

            HStack {
                Button(L10n.save) {
                    let newExercise = Exercise(
                        name: name,
                        weight: Int(weight) ?? 0,
                        reps: Int(reps) ?? 0,
                        sets: Int(sets) ?? 0,
                        seatSetting: seat.isEmpty ? nil : seat
                    )
                    viewModel.add(newExercise)
                    clearForm()
                }
                .disabled(name.isEmpty || weight.isEmpty || reps.isEmpty || sets.isEmpty)
                .accessibilityIdentifier(IDS.saveButton)

                Spacer()

                Button(L10n.cancel) {
                    clearForm()
                }
                .accessibilityIdentifier(IDS.cancelButton)
            }
            .padding(.top, 8)
        }
    }

    private func clearForm() {
        name = ""
        weight = ""
        reps = ""
        sets = ""
        seat = ""
        showForm = false
    }
}
