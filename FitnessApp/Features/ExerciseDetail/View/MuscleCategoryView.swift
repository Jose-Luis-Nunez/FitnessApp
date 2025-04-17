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
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text(group.displayName)
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
            .navigationBarTitle(group.displayName, displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                withAnimation { showForm.toggle() }
            }) {
                Image(systemName: showForm ? "minus" : "plus")
            }.accessibilityIdentifier(IDS.addExerciseButton))

            // FABs at the bottom
            BottomActionBarView(
                hasActiveExercise: viewModel.exercises.contains(where: { !$0.isCompleted }),
                isSetInProgress: viewModel.isSetInProgress,
                currentExercise: viewModel.currentExercise,
                currentSet: viewModel.currentSet,
                onStart: {
                    if let activeExercise = viewModel.exercises.first(where: { !$0.isCompleted }) {
                        viewModel.startSet(for: activeExercise)
                    }
                },
                onCompleteSet: {
                    viewModel.completeCurrentSet()
                },
                onReset: {
                    showResetConfirmation = true
                },
                onEditLess: {
                    currentRepsEditMode = .less
                    isEditingCurrentReps = true
                },
                onEditMore: {
                    currentRepsEditMode = .more
                    isEditingCurrentReps = true
                }
            )
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
            ForEach(viewModel.exercises.filter { !$0.isCompleted },id: \.id) { exercise in
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
        Section(header: Text(L10n.cardCreationTitle)) {
            TextField(L10n.cardCreationPlaceholderTextName, text: $name)
                .accessibilityIdentifier(IDS.nameField)
                .keyboardType(.default)

            TextField(L10n.cardCreationPlaceholderTextWeight, text: $weight)
                .accessibilityIdentifier(IDS.weightField)
                .keyboardType(.decimalPad)

            TextField(L10n.cardCreationPlaceholderTextRepetitions, text: $reps)
                .accessibilityIdentifier(IDS.repsField)
                .keyboardType(.numberPad)

            
            TextField(L10n.cardCreationPlaceholderTextSets, text: $sets)
                .accessibilityIdentifier(IDS.setsField)
                .keyboardType(.numberPad)
            
            TextField(L10n.cardCreationPlaceholderTextSeat, text: $seat)
                .accessibilityIdentifier(IDS.seatField)
                .keyboardType(.numberPad)
            
            HStack {
                Button(L10n.cardCreationSave) {
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

                Button(L10n.cardCreationCancel) {
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
