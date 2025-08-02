import SwiftUI

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

    let textColor: Color = AppStyle.Color.white
    let backgroundColor = AppStyle.Color.black
    let pickerColor: Color = AppStyle.Color.greenLight

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Spacer().frame(height: 12)

                HStack {
                    Text(title)
                        .font(.title2)
                        .foregroundColor(textColor)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer()

                    if let exercise = editingExercise {
                        Button(action: {
                            if let index = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }) {
                                viewModel.exercises.remove(at: index)
                            }
                            onCancel()
                            isPresented = false
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(AppStyle.Color.white)
                                .imageScale(.large)
                        }
                        .padding(.trailing, 8)
                    }
                }
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Übung")
                        .font(.headline)
                        .foregroundColor(textColor)

                    TextField("Name der Übung", text: $formViewModel.name)
                        .padding(12)
                        .background(AppStyle.Color.backgroundColor)
                        .cornerRadius(10)
                        .foregroundColor(textColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppStyle.Color.gray, lineWidth: 1)
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Padding.horizontal)
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sitz")
                        .font(.headline)
                        .foregroundColor(textColor)

                    HStack(spacing: 12) {
                        TextField("Einstellung 1", text: Binding(
                            get: { seatPart1 },
                            set: { newValue in
                                seatPart1 = newValue
                                updateSeat()
                            }
                        ))
                        .padding(12)
                        .background(AppStyle.Color.backgroundColor)
                        .cornerRadius(10)
                        .foregroundColor(textColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppStyle.Color.gray, lineWidth: 1)
                        )

                        TextField("Einstellung 2", text: Binding(
                            get: { seatPart2 },
                            set: { newValue in
                                seatPart2 = newValue
                                updateSeat()
                            }
                        ))
                        .padding(12)
                        .background(AppStyle.Color.backgroundColor)
                        .cornerRadius(10)
                        .foregroundColor(textColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppStyle.Color.gray, lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Padding.horizontal)
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 16)

                Divider().padding(.vertical, 8)

                IconPickerView(
                    selectedIcon: $formViewModel.selectedIconName,
                    icons: formViewModel.selectedCategory.availableIcons
                )
                .padding(.horizontal)

                HStack(alignment: .top, spacing: 0) {
                    VStack {
                        Text("Sätze")
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
                        Text("Wiederholung")
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
                        Text("Gewicht")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Picker("Weight", selection: Binding<String>(
                            get: {
                                // Convert Double to String with comma formatting
                                let weight = formViewModel.weight
                                return weight == floor(weight) ? 
                                    String(Int(weight)) : 
                                    String(weight).replacingOccurrences(of: ".", with: ",")
                            },
                            set: { newValue in
                                // Convert String back to Double
                                let weightString = newValue.replacingOccurrences(of: ",", with: ".")
                                if let weight = Double(weightString) {
                                    formViewModel.weight = weight
                                }
                            }
                        )) {
                            ForEach(weightOptions, id: \.self) { value in
                                Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }
                .frame(height: 120)

                HStack {
                    Spacer()

                    Text("Abbrechen")
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

                    Button("Speichern") {
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
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            loadSeatParts()
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
