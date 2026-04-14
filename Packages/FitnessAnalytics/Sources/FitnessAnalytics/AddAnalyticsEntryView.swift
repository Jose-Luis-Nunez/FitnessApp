import FitnessCore
import FitnessUI
import SwiftUI

public struct AddAnalyticsEntryView: View {
    public let date: Date
    public let exercise: Exercise
    public let existingEntry: AnalyticsEntry?
    public var onSave: (AnalyticsEntry) -> Void
    public var onCancel: () -> Void

    @State private var sets: [SetProgressInput] = []

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

    @State private var showNumberPad = false
    @State private var editingField: EditingField?
    @State private var editingSetIndex: Int?

    private enum EditingField {
        case weight, reps
    }

    public init(
        date: Date,
        exercise: Exercise,
        existingEntry: AnalyticsEntry? = nil,
        onSave: @escaping (AnalyticsEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.date = date
        self.exercise = exercise
        self.existingEntry = existingEntry
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

    public var body: some View {
        VStack(spacing: 0) {
            dataEntryCard

            if showNumberPad {
                CustomNumberPadView(
                    currentValue: getCurrentValue(),
                    isWeight: editingField == .weight,
                    valueType: editingField == .weight ? .decimal : .integer,
                    onValueChange: { newValue in
                        updateCurrentValue(newValue)
                    },
                    onDismiss: {
                        withAnimation(AppStyle.Animation.snapSpring) {
                            showNumberPad = false
                        }
                        editingField = nil
                        editingSetIndex = nil
                    }
                )
                .id("\(editingSetIndex ?? -1)-\(String(describing: editingField))")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: 370)
    }

    private var dataEntryCard: some View {
        VStack(spacing: 16) {
            Text(existingEntry != nil ? "Edit your data for \(DateFormatter.germanMedium.string(from: date))" : "Add your data for \(DateFormatter.germanMedium.string(from: date))")
                .font(AppStyle.Font.sectionHeadline)
                .foregroundColor(AppStyle.Color.white)
                .padding(.top, AppStyle.Padding.card)

            HStack(spacing: AppStyle.Layout.numberPadSpacing) {
                if exercise.hasWeight {
                    Text("Weight")
                        .font(AppStyle.Font.sheetCaption)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(width: 60, alignment: .leading)
                }

                Text("Reps.")
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(width: 60, alignment: .leading)

                Spacer()
            }
            .padding(.bottom, 4)

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: AppStyle.Layout.numberPadSpacing) {
                    if exercise.hasWeight {
                        let isEditingWeight = showNumberPad && editingSetIndex == index && editingField == .weight
                        Button(action: {
                            editingSetIndex = index
                            editingField = .weight
                            withAnimation(AppStyle.Animation.snapSpring) {
                                showNumberPad = true
                            }
                        }) {
                            let weightValue = index < sets.count ? sets[index].weight : 0.0
                            Text(WeightFormatter.format(weightValue))
                                .font(AppStyle.Font.tileValue)
                                .foregroundColor(AppStyle.Color.white)
                                .frame(width: 60, height: 38)
                                .background(isEditingWeight ? AppStyle.Color.green.opacity(AppStyle.Opacity.subtleStroke) : AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
                                .cornerRadius(AppStyle.CornerRadius.tile)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile)
                                        .stroke(isEditingWeight ? AppStyle.Color.green : AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: isEditingWeight ? 2 : 1)
                                )
                        }
                    }

                    let isEditingReps = showNumberPad && editingSetIndex == index && editingField == .reps
                    Button(action: {
                        editingSetIndex = index
                        editingField = .reps
                        withAnimation(AppStyle.Animation.snapSpring) {
                            showNumberPad = true
                        }
                    }) {
                        Text("\(index < sets.count ? sets[index].reps : 0)")
                            .font(AppStyle.Font.tileValue)
                            .foregroundColor(AppStyle.Color.white)
                            .frame(width: 60, height: 38)
                            .background(isEditingReps ? AppStyle.Color.green.opacity(AppStyle.Opacity.subtleStroke) : AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
                            .cornerRadius(AppStyle.CornerRadius.tile)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile)
                                    .stroke(isEditingReps ? AppStyle.Color.green : AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: isEditingReps ? 2 : 1)
                            )
                    }

                    Spacer()

                    if sets.count > 1 {
                        Button(action: {
                            if index < sets.count {
                                withAnimation {
                                    sets.remove(at: index)
                                }
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(AppStyle.Color.greenGlow)
                                .font(AppStyle.Font.numberPadSymbol)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !showNumberPad {
                HStack {
                    Button(action: {
                        withAnimation {
                            sets.append(SetProgressInput(weight: exercise.weight, reps: exercise.reps))
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("add more sets")
                        }
                        .foregroundColor(AppStyle.Color.greenGlow)
                        .padding(.vertical, 6)
                    }
                    Spacer()
                }

                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .background(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
                    .cornerRadius(AppStyle.CornerRadius.defaultButton)

                    Spacer()

                    Button("Save") {
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
                    }
                    .disabled(exercise.hasWeight
                        ? sets.contains(where: { $0.weight == 0 || $0.reps == 0 })
                        : sets.contains(where: { $0.reps == 0 })
                    )
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 22)
                    .background(
                        (exercise.hasWeight
                            ? sets.allSatisfy { $0.weight > 0 && $0.reps > 0 }
                            : sets.allSatisfy { $0.reps > 0 })
                        ? AppStyle.Color.green
                        : AppStyle.Color.green.opacity(AppStyle.Opacity.subtleStroke)
                    )
                    .cornerRadius(AppStyle.CornerRadius.defaultButton)
                }
                .padding(.horizontal, AppStyle.Layout.numberPadSpacing)
                .padding(.top, AppStyle.Layout.numberPadSpacing)
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, AppStyle.Padding.titleTop)
        .padding(.bottom, showNumberPad ? AppStyle.Padding.titleTop : AppStyle.CornerRadius.sheet)
        .background(AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
    }

    private func getCurrentValue() -> Double {
        guard let setIndex = editingSetIndex, setIndex < sets.count else { return 0.0 }
        switch editingField {
        case .weight:
            return sets[setIndex].weight
        case .reps:
            return Double(sets[setIndex].reps)
        case .none:
            return 0.0
        }
    }

    private func updateCurrentValue(_ newValue: Double) {
        guard let setIndex = editingSetIndex, setIndex < sets.count else { return }
        switch editingField {
        case .weight:
            sets[setIndex].weight = newValue
        case .reps:
            sets[setIndex].reps = Int(newValue)
        case .none:
            break
        }
    }
}
