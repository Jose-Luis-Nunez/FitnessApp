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
    let group: MuscleCategoryGroup

    @StateObject private var viewModel: MuscleCategoryViewModel

    @State private var showForm = false
    @State private var name = ""
    @State private var weight = ""
    @State private var reps = ""
    @State private var sets = ""
    @State private var seat = ""

    init(group: MuscleCategoryGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: MuscleCategoryViewModel(group: group))
    }

    var body: some View {
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

            Spacer()
        }
        .navigationBarTitle(group.rawValue, displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            withAnimation { showForm.toggle() }
        }) {
            Image(systemName: showForm ? "minus" : "plus")
        }.accessibilityIdentifier(IDS.addExerciseButton))
    }

    private var exerciseListSection: some View {
        ForEach(viewModel.exercises) { exercise in
            ExerciseCardView(
                viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                    viewModel.updateExercise(updated)
                }
            )
            .padding(.vertical, 4)
        }
        .onDelete(perform: viewModel.delete)
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
