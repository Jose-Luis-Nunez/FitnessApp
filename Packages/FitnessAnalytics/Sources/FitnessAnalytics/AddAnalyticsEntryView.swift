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
        ZStack {
            VStack(spacing: 16) {
                Text(existingEntry != nil ? "Edit your data for \(DateFormatter.germanMedium.string(from: date))" : "Add your data for \(DateFormatter.germanMedium.string(from: date))")
                    .font(.headline)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 14)

                HStack(spacing: 12) {
                    if exercise.hasWeight {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(AppStyle.Color.white)
                            .frame(width: 60, alignment: .leading)
                    }

                    Text("Reps.")
                        .font(.caption)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(width: 60, alignment: .leading)

                    Spacer()
                }
                .padding(.horizontal, 0)
                .padding(.bottom, 4)

                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    HStack(spacing: 12) {
                        if exercise.hasWeight {
                            Button(action: {
                                editingSetIndex = index
                                editingField = .weight
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNumberPad = true
                                }
                            }) {
                                let weightValue = index < sets.count ? sets[index].weight : 0.0
                                Text(weightValue == floor(weightValue) ? "\(Int(weightValue))" : String(weightValue).replacingOccurrences(of: ".", with: ","))
                                    .font(AppStyle.Font.tileValue)
                                    .foregroundColor(AppStyle.Color.white)
                                    .frame(width: 60, height: 38)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            }
                        }

                        Button(action: {
                            editingSetIndex = index
                            editingField = .reps
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNumberPad = true
                            }
                        }) {
                            Text("\(index < sets.count ? sets[index].reps : 0)")
                                .font(AppStyle.Font.tileValue)
                                .foregroundColor(AppStyle.Color.white)
                                .frame(width: 60, height: 38)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)

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
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 22)
                    .background(
                        (exercise.hasWeight
                            ? sets.allSatisfy { $0.weight > 0 && $0.reps > 0 }
                            : sets.allSatisfy { $0.reps > 0 })
                        ? AppStyle.Color.green
                        : AppStyle.Color.green.opacity(0.15)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 22)
            .background(AppStyle.Color.exerciseCardBackground)
            .cornerRadius(18)
            .frame(maxWidth: 370)

            if showNumberPad {
                GeometryReader { geometry in
                    VStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNumberPad = false
                                }
                                editingField = nil
                                editingSetIndex = nil
                            }

                        CustomNumberPadView(
                            currentValue: getCurrentValue(),
                            isWeight: editingField == .weight,
                            valueType: editingField == .weight ? .decimal : .integer,
                            onValueChange: { newValue in
                                updateCurrentValue(newValue)
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNumberPad = false
                                }
                                editingField = nil
                                editingSetIndex = nil
                            }
                        )
                        .frame(maxHeight: geometry.size.height * 0.5)
                    }
                    .background(Color.black.opacity(0.5))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
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
