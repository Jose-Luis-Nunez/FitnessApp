import FitnessCore
import FitnessUI
import SwiftUI

public struct AddAnalyticsEntryView: View {
    public let date: Date
    public let exercise: Exercise
    public let existingEntry: AnalyticsEntry?
    @Binding public var isPresented: Bool
    public var onSave: (AnalyticsEntry) -> Void
    public var onCancel: () -> Void

    @State private var sets: [SetProgressInput] = []
    @State private var editingSetIndex: Int?
    @State private var editingField: EditingField?
    @State private var showDecimal: Bool = false

    private enum EditingField {
        case reps, weight
    }

    public struct SetProgressInput: Identifiable {
        public let id: UUID
        public var weight: Double
        public var reps: Int

        public init(id: UUID = UUID(), weight: Double, reps: Int) {
            self.id = id
            self.weight = weight
            self.reps = reps
        }
    }

    private let repsRange = 1...99
    private let textColor: Color = AppStyle.Color.white
    private let pickerColor: Color = AppStyle.Color.greenLight

    private var weightOptions: [String] {
        let all = WeightOptionsGenerator.exerciseWeightOptions
        return showDecimal ? all : all.filter { !$0.contains(",") && !$0.contains(".") }
    }

    public init(
        date: Date,
        exercise: Exercise,
        existingEntry: AnalyticsEntry? = nil,
        isPresented: Binding<Bool>,
        onSave: @escaping (AnalyticsEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.date = date
        self.exercise = exercise
        self.existingEntry = existingEntry
        _isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel

        if let existingEntry = existingEntry {
            _sets = State(initialValue: existingEntry.setProgress.map { setProgress in
                SetProgressInput(weight: setProgress.weight, reps: setProgress.currentReps)
            })
        } else {
            _sets = State(initialValue: [
                SetProgressInput(weight: exercise.weight, reps: exercise.reps)
            ])
        }
    }

    private var isSaveDisabled: Bool {
        exercise.hasWeight
            ? sets.contains(where: { $0.weight == 0 || $0.reps == 0 })
            : sets.contains(where: { $0.reps == 0 })
    }

    private var isEditing: Bool { editingSetIndex != nil && editingField != nil }

    private func dismissPicker() {
        editingSetIndex = nil
        editingField = nil
    }

    private func dismiss() {
        onCancel()
        isPresented = false
    }

    private func saveAndDismiss() {
        let entry = AnalyticsEntry(
            exerciseId: exercise.id,
            date: date,
            setProgress: sets.map { input in
                SetProgress(
                    status: .completedDone,
                    currentReps: input.reps,
                    weight: input.weight
                )
            }
        )
        onSave(entry)
        isPresented = false
    }

    // MARK: - Body

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            allowBackdropDismiss: !isEditing,
            onCancel: {
                if isEditing {
                    dismissPicker()
                } else {
                    onCancel()
                }
            },
            actions: {
                if isEditing {
                    ExercisePickerActionButtons(
                        saveLabel: "Select",
                        saveDisabled: false,
                        onCancel: { dismissPicker() },
                        onSave: { dismissPicker() }
                    )
                } else {
                    ExercisePickerActionButtons(
                        saveDisabled: isSaveDisabled,
                        onCancel: { dismiss() },
                        onSave: { saveAndDismiss() }
                    )
                }
            },
            content: {
                if let idx = editingSetIndex, let field = editingField {
                    wheelPickerContent(index: idx, field: field)
                } else {
                    dataEntryContent
                }
            }
        )
        .onAppear {
            if sets.contains(where: { $0.weight != floor($0.weight) }) {
                showDecimal = true
            }
        }
    }

    // MARK: - Fields View

    private var dataEntryContent: some View {
        VStack(spacing: 16) {
            Text(existingEntry != nil
                 ? "Edit data for \(DateFormatter.germanMedium.string(from: date))"
                 : "Data for \(DateFormatter.germanMedium.string(from: date))")
                .font(AppStyle.Font.sheetTitle)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, AppStyle.Padding.titleTop)

            HStack(spacing: AppStyle.Layout.numberPadSpacing) {
                if exercise.hasWeight {
                    Text("Weight")
                        .font(AppStyle.Font.sheetSectionLabel)
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text("Reps")
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .center)

                if sets.count > 1 {
                    Color.clear.frame(width: 28)
                }
            }
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        HStack(spacing: AppStyle.Layout.numberPadSpacing) {
                            if exercise.hasWeight {
                                Button(action: {
                                    editingSetIndex = index
                                    editingField = .weight
                                }) {
                                    Text(WeightFormatter.format(set.weight))
                                        .font(AppStyle.Font.sectionTitle)
                                        .foregroundColor(textColor)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
                                        .cornerRadius(AppStyle.CornerRadius.tile)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile)
                                                .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                                        )
                                }
                            }

                            Button(action: {
                                editingSetIndex = index
                                editingField = .reps
                            }) {
                                Text("\(set.reps)")
                                    .font(AppStyle.Font.sectionTitle)
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
                                    .cornerRadius(AppStyle.CornerRadius.tile)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile)
                                            .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                                    )
                            }

                            if sets.count > 1 {
                                Button(action: {
                                    _ = sets.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(AppStyle.Color.greenGlow)
                                        .font(AppStyle.Font.numberPadSymbol)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 300)
            .fixedSize(horizontal: false, vertical: true)

            if !isEditing {
                HStack {
                    Spacer()
                    Button(action: {
                        sets.append(SetProgressInput(weight: exercise.weight, reps: exercise.reps))
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("add more sets")
                        }
                        .foregroundColor(AppStyle.Color.greenGlow)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.bottom, AppStyle.Layout.sheetContentBottomPad)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Wheel Picker Content

    @ViewBuilder
    private func wheelPickerContent(index: Int, field: EditingField) -> some View {
        VStack(spacing: 8) {
            Text(field == .reps ? "Reps" : "Weight")
                .font(AppStyle.Font.sheetTitle)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("Decimal")
                        .font(AppStyle.Font.defaultFont)
                        .foregroundColor(textColor.opacity(0.85))
                    Toggle("", isOn: $showDecimal)
                        .labelsHidden()
                        .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: AppStyle.Color.gray.opacity(AppStyle.Opacity.fadedOverlay)))
                }
            }
            .opacity(field == .weight ? 1 : 0)
        }
        .padding(.bottom, AppStyle.Padding.titleTop)

        switch field {
        case .reps:
            Picker("Reps", selection: Binding(
                get: { sets[index].reps },
                set: { sets[index].reps = $0 }
            )) {
                ForEach(repsRange, id: \.self) { value in
                    Text("\(value)").tag(value).foregroundColor(pickerColor)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.menu)
            #endif
            .frame(maxWidth: 200)
            .clipped()
            .frame(height: 150)

        case .weight:
            Picker("Weight", selection: Binding(
                get: { WeightFormatter.format(sets[index].weight) },
                set: { if let w = WeightFormatter.parse($0) { sets[index].weight = w } }
            )) {
                ForEach(weightOptions, id: \.self) { value in
                    Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.menu)
            #endif
            .frame(maxWidth: 200)
            .clipped()
            .frame(height: 150)
        }
    }
}
