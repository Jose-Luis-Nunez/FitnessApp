import FitnessCore
import FitnessResources
import FitnessUI
import SwiftUI

public struct AddAnalyticsEntryView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    public let date: Date
    public let exercise: Exercise
    public let existingEntry: AnalyticsEntry?
    @Binding public var isPresented: Bool
    public var onSave: (AnalyticsEntry) -> Void
    public var onCancel: () -> Void
    public let dateFormatter: DateFormatter?

    @State private var formState: AnalyticsEntryFormState
    @State private var editingSetIndex: Int?
    @State private var editingField: EditingField?
    @State private var showDecimal: Bool = false

    private enum EditingField {
        case reps, weight
    }

    private let repsRange = 1...99
    private let textColor: Color = AppStyle.Color.white
    private var pickerColor: Color { appColorTheme.accent.light }

    private var weightOptions: [Double] {
        let all = WeightOptionsGenerator.exerciseWeightOptions
        return showDecimal ? all : all.filter { $0 == floor($0) }
    }

    public init(
        date: Date,
        exercise: Exercise,
        existingEntry: AnalyticsEntry? = nil,
        isPresented: Binding<Bool>,
        dateFormatter: DateFormatter? = nil,
        onSave: @escaping (AnalyticsEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.date = date
        self.exercise = exercise
        self.existingEntry = existingEntry
        _isPresented = isPresented
        self.dateFormatter = dateFormatter
        self.onSave = onSave
        self.onCancel = onCancel

        _formState = State(
            initialValue: AnalyticsEntryFormState(
                exercise: exercise,
                existingEntry: existingEntry
            )
        )
    }

    private var isSaveDisabled: Bool {
        formState.isSaveDisabled(hasWeight: exercise.hasWeight)
    }

    private var isEditing: Bool { editingSetIndex != nil && editingField != nil }

    private func dismissPicker() {
        editingSetIndex = nil
        editingField = nil
    }

    private func dismiss() {
        onCancel()
        isPresented = false
    }

    private func saveAndDismiss() {
        let entry = formState.makeEntry(exerciseId: exercise.id, date: date)
        onSave(entry)
        isPresented = false
    }

    // MARK: - Body

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            allowBackdropDismiss: !isEditing,
            onCancel: {
                if isEditing {
                    dismissPicker()
                } else {
                    onCancel()
                }
            },
            actions: {
                if isEditing {
                    ExercisePickerActionButtons(
                        saveLabel: AppText.actionSelect,
                        saveDisabled: false,
                        onCancel: { dismissPicker() },
                        onSave: { dismissPicker() }
                    )
                } else {
                    ExercisePickerActionButtons(
                        saveDisabled: isSaveDisabled,
                        onCancel: { dismiss() },
                        onSave: { saveAndDismiss() },
                        saveAccessibilityIdentifier: FitnessCore.AnalyticsIDs.entrySaveButton
                    )
                }
            },
            content: {
                if let idx = editingSetIndex, let field = editingField {
                    wheelPickerContent(index: idx, field: field)
                } else {
                    dataEntryContent
                }
            }
        )
        .onAppear {
            if formState.sets.contains(where: { $0.weight != floor($0.weight) }) {
                showDecimal = true
            }
        }
    }

    // MARK: - Fields View

    private var dataEntryContent: some View {
        VStack(spacing: 16) {
            Text(existingEntry != nil
                 ? AppText.analyticsEditDataFor(date: formattedDate)
                 : AppText.analyticsDataFor(date: formattedDate))
                .font(AppStyle.Font.sheetTitle)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, AppStyle.Padding.titleTop)

            HStack(spacing: AppStyle.Layout.analyticsInputSpacing) {
                if formState.isBilateral {
                    Color.clear
                        .frame(width: AppStyle.Layout.analyticsInputSideWidth)
                }

                if exercise.hasWeight {
                    Text(AppText.profileWeight)
                        .font(AppStyle.Font.sheetSectionLabel)
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text(AppText.exerciseReps)
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .center)

                if formState.isBilateral || formState.sets.count > 1 {
                    Color.clear
                        .frame(width: AppStyle.Layout.analyticsInputActionWidth)
                }
            }
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 0) {
                    if formState.isBilateral {
                        ForEach(formState.logicalSetIndices, id: \.self) { logicalIndex in
                            bilateralInputGroup(logicalIndex: logicalIndex)
                        }
                    } else {
                        ForEach(Array(formState.sets.enumerated()), id: \.element.id) { index, _ in
                            inputRow(
                                index: index,
                                side: nil,
                                showsDelete: formState.sets.count > 1
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            .fixedSize(horizontal: false, vertical: true)

            if !isEditing {
                HStack {
                    Spacer()
                    Button(action: {
                        formState.appendSet(
                            defaultWeight: exercise.weight,
                            defaultReps: exercise.reps
                        )
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(AppText.trainingAddMoreSets)
                        }
                        .foregroundColor(appColorTheme.accent.glow)
                        .padding(.vertical, 6)
                    }
                    .accessibilityIdentifier(AnalyticsIDs.entryAddSetButton)
                }
                .padding(.bottom, AppStyle.Layout.sheetContentBottomPad)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func bilateralInputGroup(logicalIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: AppStyle.Layout.bilateralColumnSpacing) {
            HStack {
                Text(AppText.exerciseSetNumber(number: logicalIndex + 1))
                    .font(AppStyle.Font.sectionHeadline)
                    .foregroundColor(textColor)
                Spacer()
                if formState.logicalSetIndices.count > 1 {
                    Button {
                        formState.removeLogicalSet(at: logicalIndex)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(appColorTheme.accent.glow)
                            .font(AppStyle.Font.numberPadSymbol)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(ExerciseSide.allCases, id: \.self) { side in
                if let index = formState.index(
                    logicalSetIndex: logicalIndex,
                    side: side
                ) {
                    inputRow(index: index, side: side, showsDelete: false)
                }
            }
        }
        .padding(.vertical, AppStyle.Padding.cardVertical)
    }

    private func inputRow(
        index: Int,
        side: ExerciseSide?,
        showsDelete: Bool
    ) -> some View {
        HStack(spacing: AppStyle.Layout.analyticsInputSpacing) {
            if let side {
                Text(verbatim: side == .left ? "L" : "R")
                    .font(AppStyle.Font.sectionHeadline)
                    .foregroundColor(appColorTheme.accent.glow)
                    .frame(width: AppStyle.Layout.analyticsInputSideWidth)
            }

            if exercise.hasWeight {
                Button {
                    editingSetIndex = index
                    editingField = .weight
                } label: {
                    inputTile(WeightFormatter.displayWeight(formState.sets[index].weight, locale: locale))
                }
                .accessibilityIdentifier(
                    FitnessCore.AnalyticsIDs.entryWeightField(
                        logicalSet: formState.sets[index].logicalSetIndex ?? index,
                        side: side
                    )
                )
            }

            Button {
                editingSetIndex = index
                editingField = .reps
            } label: {
                inputTile(formState.sets[index].reps.formatted(.number.locale(locale)))
            }
            .accessibilityIdentifier(
                FitnessCore.AnalyticsIDs.entryRepsField(
                    logicalSet: formState.sets[index].logicalSetIndex ?? index,
                    side: side
                )
            )

            if showsDelete {
                Button {
                    formState.removePhysicalSet(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(appColorTheme.accent.glow)
                        .font(AppStyle.Font.numberPadSymbol)
                }
                .buttonStyle(.plain)
                .frame(width: AppStyle.Layout.analyticsInputActionWidth)
            } else if formState.isBilateral {
                Color.clear
                    .frame(width: AppStyle.Layout.analyticsInputActionWidth)
            }
        }
        .padding(.vertical, AppStyle.Layout.bilateralColumnSpacing)
    }

    private func inputTile(_ value: String) -> some View {
        Text(verbatim: value)
            .font(AppStyle.Font.sectionTitle)
            .foregroundColor(textColor)
            .lineLimit(1)
            .minimumScaleFactor(AppStyle.Layout.analyticsInputMinimumScaleFactor)
            .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.minimumTapTargetSize)
            .background(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
            .cornerRadius(AppStyle.CornerRadius.tile)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile)
                    .stroke(
                        AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke),
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Wheel Picker Content

    @ViewBuilder
    private func wheelPickerContent(index: Int, field: EditingField) -> some View {
        VStack(spacing: 8) {
            Text(field == .reps ? AppText.exerciseReps : AppText.profileWeight)
                .font(AppStyle.Font.sheetTitle)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text(AppText.commonDecimal)
                        .font(AppStyle.Font.defaultFont)
                        .foregroundColor(textColor.opacity(0.85))
                    Toggle("", isOn: $showDecimal)
                        .labelsHidden()
                        .toggleStyle(CapsuleToggleStyle(onColor: appColorTheme.accent.glow, offColor: AppStyle.Color.gray.opacity(AppStyle.Opacity.fadedOverlay)))
                }
            }
            .opacity(field == .weight ? 1 : 0)
        }
        .padding(.bottom, AppStyle.Padding.titleTop)

        switch field {
        case .reps:
            Picker(AppText.exerciseReps, selection: Binding(
                get: { formState.sets[index].reps },
                set: { formState.sets[index].reps = $0 }
            )) {
                ForEach(repsRange, id: \.self) { value in
                    Text(verbatim: value.formatted(.number.locale(locale))).tag(value).foregroundColor(pickerColor)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.menu)
            #endif
            .frame(maxWidth: 200)
            .clipped()
            .frame(height: 150)

        case .weight:
            Picker(AppText.profileWeight, selection: Binding(
                get: { formState.sets[index].weight },
                set: { formState.sets[index].weight = $0 }
            )) {
                ForEach(weightOptions, id: \.self) { value in
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
            .frame(maxWidth: 200)
            .clipped()
            .frame(height: 150)
        }
    }

    private var formattedDate: String {
        if let dateFormatter { return dateFormatter.string(from: date) }
        return date.formatted(.dateTime.day().month(.wide).year().locale(locale))
    }
}
