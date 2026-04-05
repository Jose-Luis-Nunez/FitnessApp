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
    @State private var validIconOptions: [String] = []

    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }

    let textColor: Color = AppStyle.Color.white
    let backgroundColor = AppStyle.Color.black
    let pickerColor: Color = AppStyle.Color.greenLight

    var body: some View {
        ZStack {
            // Dimmed backdrop; tap outside closes
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                    isPresented = false
                }

            // Bottom sheet panel
            VStack(spacing: 0) {
                // Grabber handle
                Capsule()
                    .fill(Color.white.opacity(0.35))
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
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppStyle.Color.green)
                            .padding(.leading, 2)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text("Decimal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.85))
                        Toggle("", isOn: $showDecimal)
                            .labelsHidden()
                            .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
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

                HStack(alignment: .top, spacing: 0) {
                    VStack {
                        Text("Set")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Picker("Sets", selection: $formViewModel.sets) {
                            ForEach(setsRange, id: \.self) { value in
                                Text("\(value)").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }

                    VStack {
                        Text("Reps")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Picker("Reps", selection: $formViewModel.reps) {
                            ForEach(repsRange, id: \.self) { value in
                                Text("\(value)").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }

                    VStack {
                        Text("Weight")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Picker("Weight", selection: Binding<String>(
                            get: {
                                return WeightFormatter.format(formViewModel.weight)
                            },
                            set: { newValue in
                                if let weight = WeightFormatter.parse(newValue) {
                                    formViewModel.weight = weight
                                }
                            }
                        )) {
                            ForEach(filteredWeightOptions, id: \.self) { value in
                                Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }
                .frame(height: 150)

                HStack {
                    Spacer()

                    Text("Cancel")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .padding(5)
                        .frame(width: 120)
                        .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                        .onTapGesture {
                            onCancel()
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer()

                    Button("Save") {
                        onSave()
                        isPresented = false
                    }
                    .foregroundColor(saveDisabled ? Color.white : Color.white)
                    .font(.system(size: 14))
                    .padding(5)
                    .frame(width: 140, height: 40)
                    .background(saveDisabled ? AppStyle.Color.green.opacity(0.15) : AppStyle.Color.green)
                    .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                    .disabled(saveDisabled)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Spacer()
                }
                .padding(.horizontal, 5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: "#222025"))
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 520, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
            .opacity(isContentVisible ? 1 : 0)
            .allowsHitTesting(isContentVisible)
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
            // Defaults im Add-Flow setzen
            if editingExercise == nil {
                formViewModel.sets = max(setsRange.lowerBound, min(setsRange.upperBound, 3))
                formViewModel.reps = max(repsRange.lowerBound, min(repsRange.upperBound, 12))
                // Gewicht auf 20 setzen, falls vorhanden
                if weightOptions.contains("20") || weightOptions.contains("20,0") || weightOptions.contains("20.0") {
                    formViewModel.weight = 20
                }
            }
            withAnimation(.easeOut(duration: 0.18)) { isContentVisible = true }
        }
        .onChange(of: isPresented) { newValue in
            if !newValue { isContentVisible = false }
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

