import SwiftUI
import UIKit

struct ActiveSetEditPickerView: View {
    let title: String
    @Binding var selectedReps: String
    @Binding var selectedWeight: String
    let repsRange: ClosedRange<Int>
    let weightOptions: [String]
    let onSave: (Int, Double) -> Void
    let onCancel: () -> Void
    let saveDisabled: Bool
    
    let textColor: Color = AppStyle.Color.white
    let pickerColor: Color = AppStyle.Color.greenLight

    @State private var showDecimal: Bool = false
    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(alignment: .center, spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(AppStyle.Opacity.grabberHandle))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .foregroundColor(textColor)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text("Decimal")
                                .font(AppStyle.Font.tileLabel)
                                .foregroundColor(textColor.opacity(0.85))
                            Toggle("", isOn: $showDecimal)
                                .labelsHidden()
                                .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
                        }
                    }
                }
                .padding(.bottom, 18)

                VStack(spacing: 0) {
                    HStack {
                        Text("Wiederholung")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Text("Gewicht")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                    }

                    HStack {
                        Picker("Reps", selection: $selectedReps) {
                            ForEach(repsRange.map(String.init), id: \.self) { value in
                                Text(value).tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("Weight", selection: $selectedWeight) {
                            ForEach(filteredWeightOptions, id: \.self) { value in
                                Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 120)
                }

                ExercisePickerActionButtons(
                    saveDisabled: saveDisabled,
                    onCancel: { onCancel() },
                    onSave: {
                        if let reps = Int(selectedReps),
                           let weight = WeightFormatter.parse(selectedWeight) {
                            onSave(reps, weight)
                        }
                    }
                )
            }
            .exercisePickerSheet(isContentVisible: true)
            .frame(minHeight: 420, alignment: .bottom)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 80 {
                        onCancel()
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if selectedWeight.contains(",") || selectedWeight.contains(".") {
                showDecimal = true
            }
        }
    }
}
