import SwiftUI
import FitnessResources
import FitnessUI

public struct ExerciseWeightPickerView: View {
    @Bindable public var formViewModel: ExerciseFormViewModel
    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void
    public let repsRange: ClosedRange<Int>
    public let weightOptions: [String]
    public let setsRange: ClosedRange<Int>

    @State private var showDecimal: Bool = false

    public init(
        formViewModel: ExerciseFormViewModel,
        isPresented: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        repsRange: ClosedRange<Int>,
        weightOptions: [String],
        setsRange: ClosedRange<Int>
    ) {
        self.formViewModel = formViewModel
        _isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel
        self.repsRange = repsRange
        self.weightOptions = weightOptions
        self.setsRange = setsRange
    }

    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }

    private var hasWeight: Bool {
        formViewModel.editingExercise?.hasWeight ?? (formViewModel.weight > 0)
    }

    private let textColor: Color = AppStyle.Color.white

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            onCancel: onCancel,
            actions: {
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
            },
            content: {
                VStack(spacing: 8) {
                    Text(L10n.cardEditTitle)
                        .font(AppStyle.Font.sheetTitle)
                        .foregroundColor(textColor)
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
                                    .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: AppStyle.Color.gray.opacity(AppStyle.Opacity.fadedOverlay)))
                            }
                        }
                    }
                }
                .padding(.bottom, AppStyle.Padding.sectionSpacing)

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
            }
        )
        .onAppear {
            let w = formViewModel.weight
            if w != floor(w) { showDecimal = true }
        }
    }
}
