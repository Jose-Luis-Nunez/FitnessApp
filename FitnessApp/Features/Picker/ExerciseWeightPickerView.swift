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

    private var hasWeight: Bool {
        formViewModel.editingExercise?.hasWeight ?? (formViewModel.weight > 0)
    }

    private let textColor: Color = AppStyle.Color.white
    private let pickerColor: Color = AppStyle.Color.greenLight

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

                VStack(spacing: 8) {
                    Text(L10n.cardEditTitle)
                        .font(.title2)
                        .foregroundColor(textColor)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    if hasWeight {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Text("Decimal")
                                    .font(AppStyle.Font.defaultFont)
                                    .foregroundColor(textColor.opacity(0.85))
                                Toggle("", isOn: $showDecimal)
                                    .labelsHidden()
                                    .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
                            }
                        }
                        .padding(.horizontal, AppStyle.Padding.horizontal)
                    }
                }
                .padding(.bottom, 18)

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
                    showWeight: hasWeight
                )

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
