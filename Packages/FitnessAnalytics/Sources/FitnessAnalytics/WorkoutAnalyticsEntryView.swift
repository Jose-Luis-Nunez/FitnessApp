import FitnessCore
import FitnessUI
import SwiftUI

enum WorkoutAnalyticsSummary {
    static func text(for draft: WorkoutAnalyticsExerciseDraft) -> String {
        let progress = draft.entry.setProgress
        let reps = Set(progress.map(\.currentReps))
        let weights = Set(progress.map(\.weight))
        let setText = "\(draft.setCount) \(draft.setCount == 1 ? "set" : "sets")"
        let repsText: String
        if let repsValue = reps.count == 1 ? reps.first : nil {
            repsText = "\(repsValue) \(repsValue == 1 ? "rep" : "reps")"
        } else {
            repsText = "variable reps"
        }

        guard draft.exercise.hasWeight else {
            return "\(setText) · \(repsText)"
        }

        let weightText = weights.count == 1
            ? WeightFormatter.displayWeight(weights.first ?? 0)
            : "variable weight"
        return "\(weightText) · \(setText) · \(repsText)"
    }
}

public struct WorkoutAnalyticsEntryView: View {
    @Binding private var isPresented: Bool
    @State private var viewModel: WorkoutAnalyticsEntryViewModel
    @State private var showCalendar = false
    @State private var editingExerciseID: UUID?
    @AppStorage(DefaultIconColorScheme.storageKey)
    private var iconColorScheme: DefaultIconColorScheme = .green

    public init(workout: Workout, isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _viewModel = State(
            initialValue: WorkoutAnalyticsEntryViewModel(workout: workout)
        )
    }

    public var body: some View {
        ZStack {
            OverlaySheetContainer(
                isPresented: $isPresented,
                allowBackdropDismiss: viewModel.saveState == .editing,
                backgroundColor: AppStyle.Color.backgroundColor,
                expandsToTop: true,
                onCancel: {},
                actions: {
                    ExercisePickerActionButtons(
                        saveLabel: "Save Workout",
                        saveDisabled: !viewModel.canSave,
                        onCancel: { isPresented = false },
                        onSave: { saveAndDismiss() },
                        saveAccessibilityIdentifier: WorkoutAnalyticsIDs.saveButton
                    )
                },
                content: {
                    content
                }
            )
            .disabled(viewModel.saveState != .editing)

            CalendarDialogView(
                isPresented: $showCalendar,
                selectedDate: $viewModel.selectedDate,
                title: "Workout Date",
                locale: Locale(identifier: "en_US")
            )

            if let editingExerciseID,
               let draft = viewModel.draft(for: editingExerciseID) {
                AddAnalyticsEntryView(
                    date: viewModel.selectedDate,
                    exercise: draft.exercise,
                    existingEntry: draft.entry,
                    isPresented: detailPresentationBinding,
                    dateFormatter: Self.dateFormatter,
                    onSave: { entry in
                        viewModel.updateDraft(
                            exerciseId: editingExerciseID,
                            with: entry
                        )
                        self.editingExerciseID = nil
                    },
                    onCancel: {
                        self.editingExerciseID = nil
                    }
                )
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: AppStyle.Padding.card) {
            header
            dateButton
            selectionHeader

            if let saveErrorMessage = viewModel.saveErrorMessage {
                Text(saveErrorMessage)
                    .font(AppStyle.Font.detailCaption)
                    .foregroundColor(AppStyle.Color.error)
            }

            if viewModel.drafts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: ExerciseCardLayout.CategoryTile.verticalSpacing) {
                    ForEach(viewModel.drafts) { draft in
                        draftRow(draft)
                    }
                }
            }
        }
        .padding(.bottom, AppStyle.Padding.card)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppStyle.Padding.cardVertical) {
            Text("Log Workout")
                .font(AppStyle.Font.navigationHeadline)
                .foregroundColor(AppStyle.Color.white)
                .accessibilityIdentifier(WorkoutAnalyticsIDs.screen)

            Text(viewModel.workout.name)
                .font(AppStyle.Font.sheetSectionLabel)
                .foregroundColor(
                    AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateButton: some View {
        Button {
            showCalendar = true
        } label: {
            HStack {
                Image(systemName: "calendar")
                Text(Self.dateFormatter.string(from: viewModel.selectedDate))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(AppStyle.Font.defaultFont)
            .foregroundColor(AppStyle.Color.greenGlow)
            .padding(.horizontal, AppStyle.Padding.card)
            .frame(minHeight: AppStyle.Layout.minimumTapTargetSize)
        }
        .buttonStyle(.plain)
        .background {
            CardBackground(style: .idle, addPadding: false) {
                Color.clear
            }
        }
        .accessibilityIdentifier(WorkoutAnalyticsIDs.dateButton)
    }

    private var selectionHeader: some View {
        Text("\(viewModel.selectedCount) of \(viewModel.drafts.count) exercises")
            .font(AppStyle.Font.sheetSectionLabel)
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Text("This workout has no active exercises.")
            .font(AppStyle.Font.defaultFont)
            .foregroundColor(
                AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel)
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, AppStyle.Padding.card)
    }

    private func draftRow(_ draft: WorkoutAnalyticsExerciseDraft) -> some View {
        HStack(spacing: 0) {
            Button {
                viewModel.toggleSelection(for: draft.id)
            } label: {
                HStack(spacing: AppStyle.Padding.card) {
                    HStack(spacing: AppStyle.Padding.cardVertical) {
                        selectionIndicator(isSelected: draft.isSelected)
                        selectionIcon(for: draft.exercise)
                    }

                    VStack(
                        alignment: .leading,
                        spacing: AppStyle.Padding.cardVertical
                    ) {
                        Text(draft.exercise.name)
                            .font(AppStyle.Font.cardHeadline)
                            .foregroundColor(AppStyle.Color.white)

                        Text(WorkoutAnalyticsSummary.text(for: draft))
                            .font(AppStyle.Font.detailCaption)
                            .foregroundColor(
                                AppStyle.Color.white.opacity(
                                    AppStyle.Opacity.secondaryLabel
                                )
                            )
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AppStyle.Padding.card)
                .padding(.vertical, AppStyle.Padding.cardVertical)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(draft.exercise.name)
            .accessibilityValue(
                draft.isSelected ? "Selected" : "Not selected"
            )
            .accessibilityIdentifier(
                WorkoutAnalyticsIDs.exerciseSelection(draft.id)
            )

            Button {
                editingExerciseID = draft.id
            } label: {
                Image(systemName: "ellipsis.vertical")
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .frame(
                        width: AppStyle.Layout.minimumTapTargetSize,
                        height: AppStyle.Layout.minimumTapTargetSize
                    )
                    .padding(.trailing, AppStyle.Padding.card)
                    .padding(.vertical, AppStyle.Padding.cardVertical)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(draft.exercise.name)")
            .accessibilityIdentifier(
                WorkoutAnalyticsIDs.exerciseDetails(draft.id)
            )
        }
        .background {
            CardBackground(style: .idle, addPadding: false) {
                Color.clear
            }
        }
    }

    private func selectionIcon(
        for exercise: Exercise
    ) -> some View {
        Image(iconColorScheme.iconName(for: exercise.displayIconName))
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(
                width: AppStyle.Layout.minimumTapTargetSize,
                height: AppStyle.Layout.minimumTapTargetSize,
                alignment: exercise.iconAlignment
            )
            .clipped()
            .frame(
                width: AppStyle.Layout.minimumTapTargetSize,
                height: AppStyle.Layout.minimumTapTargetSize
            )
            .contentShape(Rectangle())
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel),
                    lineWidth: AppStyle.Layout.selectionRadioStroke
                )
                .frame(
                    width: AppStyle.Layout.selectionRadioSize,
                    height: AppStyle.Layout.selectionRadioSize
                )

            if isSelected {
                Circle()
                    .fill(AppStyle.Color.greenGlow)
                    .frame(
                        width: AppStyle.Layout.selectionRadioDot,
                        height: AppStyle.Layout.selectionRadioDot
                    )
            }
        }
        .frame(
            width: AppStyle.Layout.selectionRadioFrame,
            height: AppStyle.Layout.selectionRadioFrame
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        return formatter
    }()

    private var detailPresentationBinding: Binding<Bool> {
        Binding(
            get: { editingExerciseID != nil },
            set: { if !$0 { editingExerciseID = nil } }
        )
    }

    private func saveAndDismiss() {
        guard viewModel.save() else { return }
        isPresented = false
    }
}
