import SwiftUI

struct ExerciseWeightPickerView: View {
    @ObservedObject var formViewModel: ExerciseFormViewModel
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let repsRange: ClosedRange<Int>
    let weightOptions: [String]
    let setsRange: ClosedRange<Int>

    @State private var isContentVisible: Bool = false
    @State private var showDecimal: Bool = false

    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }

    private let textColor: Color = AppStyle.Color.white
    private let pickerColor: Color = AppStyle.Color.greenLight

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                    isPresented = false
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    Text(L10n.cardEditTitle)
                        .font(.title2)
                        .foregroundColor(textColor)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text("Decimal")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(textColor.opacity(0.85))
                            Toggle("", isOn: $showDecimal)
                                .labelsHidden()
                                .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
                        }
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                }
                .padding(.bottom, 18)

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
                                WeightFormatter.format(formViewModel.weight)
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

                ExercisePickerActionButtons(
                    saveDisabled: false,
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
            let w = formViewModel.weight
            if w != floor(w) { showDecimal = true }
            withAnimation(.easeOut(duration: 0.18)) { isContentVisible = true }
        }
        .onChange(of: isPresented) { newValue in
            if !newValue { isContentVisible = false }
        }
    }
}
