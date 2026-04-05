import SwiftUI
import UIKit

struct ExercisePickerView: View {
    @ObservedObject var formViewModel: ExerciseFormViewModel

    let title: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let saveDisabled: Bool
    let repsRange: ClosedRange<Int>
    let weightOptions: [String]
    let setsRange: ClosedRange<Int>
    let viewModel: MuscleCategoryViewModel
    let editingExercise: Exercise?

    @State private var seatPart1: String = ""
    @State private var seatPart2: String = ""
    @State private var isContentVisible: Bool = false
    @State private var showDecimal: Bool = false
    @State private var noSeats: Bool = false
    @State private var noWeight: Bool = false
    @State private var validIconOptions: [String] = []

    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }

    let textColor: Color = AppStyle.Color.white
    let backgroundColor = AppStyle.Color.black
    let pickerColor: Color = AppStyle.Color.greenLight

    var body: some View {
        ZStack {
            Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                    isPresented = false
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(AppStyle.Opacity.grabberHandle))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                Text(title)
                    .font(.title2)
                    .foregroundColor(textColor)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let exercise = editingExercise {
                            Button(action: {
                                if let index = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }) {
                                    viewModel.exercises.remove(at: index)
                                    viewModel.saveExercises()
                                }
                                onCancel()
                                isPresented = false
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(AppStyle.Color.white)
                                    .imageScale(.large)
                            }
                        }

                        Text("Category")
                            .font(.headline)
                            .foregroundColor(textColor)

                        Text(formViewModel.selectedCategory.displayName)
                            .font(AppStyle.Font.tileValue)
                            .foregroundColor(AppStyle.Color.green)
                            .padding(.leading, 2)
                    }

                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name of Exercise")
                        .font(.headline)
                        .foregroundColor(textColor)

                    ExercisePickerInputField(text: $formViewModel.name)
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 20)

                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text("No Seats")
                            .font(AppStyle.Font.tileLabel)
                            .foregroundColor(textColor.opacity(0.85))
                        Toggle("", isOn: $noSeats)
                            .labelsHidden()
                            .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
                    }
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Seat Settings")
                        .font(.headline)
                        .foregroundColor(textColor)

                    HStack(spacing: 12) {
                        ExercisePickerInputField(prompt: "Setting 1", text: Binding(
                            get: { seatPart1 },
                            set: { newValue in
                                seatPart1 = newValue
                                updateSeat()
                            }
                        ))

                        ExercisePickerInputField(prompt: "Setting 2", text: Binding(
                            get: { seatPart2 },
                            set: { newValue in
                                seatPart2 = newValue
                                updateSeat()
                            }
                        ))
                    }
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 20)
                .opacity(noSeats ? 0.3 : 1)
                .disabled(noSeats)

                if validIconOptions.count > 1 {
                    Divider().padding(.top, 0)

                    IconPickerView(
                        selectedIcon: $formViewModel.selectedIconName,
                        icons: validIconOptions
                    )
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

                HStack {
                    if !noWeight {
                        HStack(spacing: 6) {
                            Text("Decimal")
                                .font(AppStyle.Font.tileLabel)
                                .foregroundColor(textColor.opacity(0.85))
                            Toggle("", isOn: $showDecimal)
                                .labelsHidden()
                                .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text("No Weight")
                            .font(AppStyle.Font.tileLabel)
                            .foregroundColor(textColor.opacity(0.85))
                        Toggle("", isOn: $noWeight)
                            .labelsHidden()
                            .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
                    }
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 8)

                ExerciseWheelPickerRow(
                    sets: $formViewModel.sets,
                    reps: $formViewModel.reps,
                    weight: Binding<String>(
                        get: { WeightFormatter.format(formViewModel.weight) },
                        set: { if let w = WeightFormatter.parse($0) { formViewModel.weight = w } }
                    ),
                    setsRange: setsRange,
                    repsRange: repsRange,
                    weightOptions: filteredWeightOptions,
                    showWeight: !noWeight
                )

                ExercisePickerActionButtons(
                    saveDisabled: saveDisabled,
                    onCancel: {
                        onCancel()
                        isPresented = false
                    },
                    onSave: {
                        onSave()
                        isPresented = false
                    }
                )
            }
            .exercisePickerSheet(isContentVisible: isContentVisible)
            .frame(minHeight: 520, alignment: .bottom)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 80 {
                        onCancel()
                        isPresented = false
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            loadSeatParts()
            validIconOptions = formViewModel.selectedCategory.availableIcons.filter { name in
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                return UIImage(named: name) != nil
            }
            let w = formViewModel.weight
            if w != floor(w) { showDecimal = true }
            if editingExercise != nil {
                noSeats = formViewModel.noSeats
                if w == 0 { noWeight = true }
            }
            if editingExercise == nil {
                formViewModel.sets = max(setsRange.lowerBound, min(setsRange.upperBound, 3))
                formViewModel.reps = max(repsRange.lowerBound, min(repsRange.upperBound, 12))
                // Gewicht auf 20 setzen, falls vorhanden
                if weightOptions.contains("20") || weightOptions.contains("20,0") || weightOptions.contains("20.0") {
                    formViewModel.weight = 20
                }
            }
            isContentVisible = true
        }
        .onChange(of: isPresented) { newValue in
            if !newValue { isContentVisible = false }
        }
        .onChange(of: noSeats) { isNoSeats in
            formViewModel.noSeats = isNoSeats
            if isNoSeats {
                seatPart1 = ""
                seatPart2 = ""
                updateSeat()
            }
        }
        .onChange(of: noWeight) { isNoWeight in
            if isNoWeight {
                formViewModel.weight = 0
            }
        }
    }

    private func updateSeat() {
        formViewModel.seat = [seatPart1, seatPart2]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private func loadSeatParts() {
        let parts = formViewModel.seat.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        seatPart1 = parts.count > 0 ? parts[0] : ""
        seatPart2 = parts.count > 1 ? parts[1] : ""
    }
}

