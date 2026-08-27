import SwiftUI
import FitnessResources

public struct ActiveSetEditPickerView: View {
    @Environment(\.locale) private var locale
    let title: LocalizedStringResource
    @Binding var selectedReps: String
    @Binding var selectedWeight: String
    let repsRange: ClosedRange<Int>
    let weightOptions: [Double]
    let onSave: (Int, Double) -> Void
    let onCancel: () -> Void
    let saveDisabled: Bool
    /// Visible sheet height, so Less/More occupies the same frame as the
    /// training sheet it is opened from. `nil` falls back to content sizing.
    let fixedHeight: CGFloat?
    /// How the sheet paints itself. Less/More is presented as a sibling of the
    /// training sheet, so it uses that backdrop.
    let surface: SheetSurface
    /// See `OverlaySheetContainer.ownsPresentation`.
    let ownsPresentation: Bool

    let textColor: Color = AppStyle.Color.white
    @Environment(\.appColorTheme) private var appColorTheme

    private var pickerColor: Color { appColorTheme.accent.light }

    @State private var isShown: Bool = true
    @State private var showDecimal: Bool = false
    private var filteredWeightOptions: [Double] {
        showDecimal ? weightOptions : weightOptions.filter { $0 == floor($0) }
    }

    private var selectedWeightValue: Binding<Double> {
        Binding(
            get: { WeightFormatter.parse(selectedWeight) ?? 0 },
            set: { selectedWeight = WeightFormatter.format($0, locale: locale) }
        )
    }

    public init(
        title: LocalizedStringResource,
        selectedReps: Binding<String>,
        selectedWeight: Binding<String>,
        repsRange: ClosedRange<Int>,
        weightOptions: [Double],
        onSave: @escaping (Int, Double) -> Void,
        onCancel: @escaping () -> Void,
        saveDisabled: Bool,
        fixedHeight: CGFloat? = nil,
        surface: SheetSurface = .default,
        ownsPresentation: Bool = true
    ) {
        self.title = title
        _selectedReps = selectedReps
        _selectedWeight = selectedWeight
        self.repsRange = repsRange
        self.weightOptions = weightOptions
        self.onSave = onSave
        self.onCancel = onCancel
        self.saveDisabled = saveDisabled
        self.fixedHeight = fixedHeight
        self.surface = surface
        self.ownsPresentation = ownsPresentation
    }

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isShown,
            surface: surface,
            fixedHeight: fixedHeight,
            ownsPresentation: ownsPresentation,
            onCancel: onCancel,
            actions: {
                // Same Cancel/Save treatment as the feedback sheet — the two
                // sheets sit in one flow, so their actions must not differ in
                // button size, weight, or fill.
                SheetActionButtons(
                    saveLabel: AppText.actionSave,
                    isSaveEnabled: !saveDisabled,
                    onCancel: { onCancel() },
                    onSave: {
                        if let reps = Int(selectedReps),
                           let weight = WeightFormatter.parse(selectedWeight) {
                            onSave(reps, weight)
                        }
                    }
                )
            },
            content: {
                VStack(spacing: 8) {
                    Text(title)
                        .font(AppStyle.Font.sheetTitle)
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text(AppText.commonDecimal)
                                .font(AppStyle.Font.tileLabel)
                                .foregroundColor(textColor.opacity(0.85))
                            Toggle("", isOn: $showDecimal)
                                .labelsHidden()
                                .toggleStyle(CapsuleToggleStyle(onColor: appColorTheme.accent.glow, offColor: AppStyle.Color.gray.opacity(AppStyle.Opacity.fadedOverlay)))
                        }
                    }
                }
                .padding(.bottom, AppStyle.Padding.sectionSpacing)

                // With a fixed sheet height there is far more room than the
                // wheels need, and the container puts its own spacer above the
                // action bar. This second spacer makes the two share the slack,
                // which centres the wheels in the free area instead of leaving
                // them pinned under the decimal toggle with a large gap below.
                // A fixed padding cannot do this: the slack depends on the
                // measured sheet height, so any constant is wrong on some
                // device. Omitted when the sheet is content-sized, where there
                // is no slack to distribute.
                if fixedHeight != nil {
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    HStack {
                        Text(AppText.exerciseWeight)
                            .font(AppStyle.Font.sheetSectionLabel)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Text(AppText.exerciseReps)
                            .font(AppStyle.Font.sheetSectionLabel)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                    }

                    HStack {
                        Picker(AppText.exerciseWeight, selection: selectedWeightValue) {
                            ForEach(filteredWeightOptions, id: \.self) { value in
                                Text(verbatim: WeightFormatter.displayWeight(value, locale: locale))
                                    .tag(value)
                                    .foregroundColor(pickerColor)
                            }
                        }
#if os(iOS)
                        .pickerStyle(.wheel)
#else
                        .pickerStyle(.menu)
#endif
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker(AppText.exerciseReps, selection: $selectedReps) {
                            ForEach(repsRange.map(String.init), id: \.self) { value in
                                Text(verbatim: value).tag(value).foregroundColor(pickerColor)
                            }
                        }
#if os(iOS)
                        .pickerStyle(.wheel)
#else
                        .pickerStyle(.menu)
#endif
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 120)
                }
            }
        )
        .onAppear {
            if selectedWeight.contains(",") || selectedWeight.contains(".") {
                showDecimal = true
            }
        }
    }
}
