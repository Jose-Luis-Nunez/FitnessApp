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
            Color(hex: "#13092D") // Sehr dunkler Hintergrund
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                mainContent
                bottomButtonsSection
            }
        }
        .navigationBarTitle(group.rawValue, displayMode: .inline)
        .navigationBarItems(trailing: addExerciseButton)
        .sheet(isPresented: $isEditingCurrentReps) {
            NavigationView {
                currentRepsEditSheet
            }
        }
        .alert(isPresented: $showResetConfirmation) {
            resetAlert
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: AppStyle.Layout.Card.margin) {
                exercisesList
                if showForm {
                    exerciseFormSection
                        .transition(.move(edge: .bottom))
                }
                // Add padding at the bottom to prevent the last card from being hidden
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)  // Increased horizontal padding
        }
        .padding(.horizontal, 16)  // Additional padding for ScrollView
    }
    
    private var exercisesList: some View {
        ForEach(viewModel.exercises) { exercise in
            ExerciseCardView(viewModel: ExerciseCardViewModel(
                exercise: exercise,
                onUpdate: { updatedExercise in
                    viewModel.updateExercise(updatedExercise)
                }
            ))
            .padding(.horizontal, 4)  // Small additional padding for each card
        }
    }
    
    private var exerciseFormSection: some View {
        VStack(spacing: 16) {
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                TextField("Weight", text: $weight)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Reps", text: $reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Sets", text: $sets)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            TextField("Seat (optional)", text: $seat)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("Cancel") {
                    clearForm()
                }
                .buttonStyle(.bordered)
                
                Button("Add") {
                    if let weightValue = Int(weight),
                       let repsValue = Int(reps),
                       let setsValue = Int(sets) {
                        viewModel.add(
                            name: name,
                            weight: weightValue,
                            reps: repsValue,
                            sets: setsValue,
                            seat: seat.isEmpty ? nil : seat
                        )
                        clearForm()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || weight.isEmpty || reps.isEmpty || sets.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private var addExerciseButton: some View {
        Button(action: {
            withAnimation {
                showForm.toggle()
            }
        }) {
            Image(systemName: showForm ? "minus.circle.fill" : "plus.circle.fill")
                .foregroundColor(showForm ? .red : .blue)
        }
    }
    
    private var bottomButtonsSection: some View {
        VStack {
            if let activeExercise = viewModel.exercises.first(where: { !$0.isCompleted }) {
                HStack(spacing: 16) {
                    if viewModel.state.isSetInProgress {
                        Group {
                            FitnessButton("Less", style: .secondary) {
                                currentRepsEditMode = .less
                                isEditingCurrentReps = true
                            }
                            .foregroundColor(.red)
                            
                            FitnessButton("Done!", style: .primary) {
                                viewModel.completeCurrentSet()
                            }
                            
                            FitnessButton("More", style: .secondary) {
                                currentRepsEditMode = .more
                                isEditingCurrentReps = true
                            }
                            .foregroundColor(.green)
                        }
                    } else {
                        FitnessButton(viewModel.startButtonTitle, style: .primary) {
                            viewModel.startSet(for: activeExercise)
                        }
                    }
                }
            } else {
                FitnessButton("Reset Progress", style: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
        .background(
            Rectangle()
                .fill(Color(hex: "#13092D"))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
    
    private var currentRepsEditSheet: some View {
        Form {
            Section {
                Text(currentRepsEditMode == .less ? "Weniger Wiederholungen" : "Mehr Wiederholungen")
                    .font(.headline)
                    .padding(.vertical, 8)
                
                TextField("Neue Anzahl", text: $currentRepsInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
                   let currentExercise = viewModel.state.currentExercise {
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
                guard let currentExercise = viewModel.state.currentExercise else { return true }
                switch currentRepsEditMode {
                case .less: return reps >= currentExercise.reps
                case .more: return reps <= currentExercise.reps
                }
            } ?? true)
        )
    }
    
    private var resetAlert: Alert {
        Alert(
            title: Text("Reset Progress"),
            message: Text("Do you want to reset all exercise progress? This will allow you to start the sets again."),
            primaryButton: .destructive(Text("Reset")) {
                viewModel.resetProgress()
            },
            secondaryButton: .cancel()
        )
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
