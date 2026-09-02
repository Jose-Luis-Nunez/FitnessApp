import FitnessCore
import FitnessUI
import SwiftUI
import FitnessResources

enum WorkoutAnalyticsAccessibility {
    static func value(for draft: WorkoutAnalyticsExerciseDraft, locale: Locale) -> String {
        var components = [AppText.resolve(draft.exercise.category.localizedGroupName, locale: locale)]

        if draft.exercise.hasWeight {
            let weights = Set(draft.entry.setProgress.map(\.weight))
            if weights.count == 1, let weight = weights.first {
                components.append(AppText.resolve(AppText.accessibilityKilograms(value: WeightFormatter.format(weight, locale: locale)), locale: locale))
            } else {
                components.append(AppText.resolve(AppText.accessibilityVariableWeight, locale: locale))
            }
        }

        components.append(AppText.resolve(AppText.accessibilitySetCount(count: draft.setCount), locale: locale))

        let reps = Set(draft.entry.setProgress.map(\.currentReps))
        if reps.count == 1, let repCount = reps.first {
            components.append(AppText.resolve(AppText.accessibilityRepCount(count: repCount), locale: locale))
        } else {
            components.append(AppText.resolve(AppText.accessibilityVariableReps, locale: locale))
        }

        return components.joined(separator: ", ")
    }
}

private struct WorkoutAnalyticsDraftContentLayout: Layout {
    let spacing: CGFloat
    let minimumIdentityWidth: CGFloat
    let compactSectionSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 4 else { return .zero }
        let selectionSize = subviews[0].sizeThatFits(.unspecified)
        let iconSize = subviews[1].sizeThatFits(.unspecified)
        let metricsSize = subviews[3].sizeThatFits(.unspecified)
        let minimumRegularWidth = selectionSize.width
            + iconSize.width
            + minimumIdentityWidth
            + metricsSize.width
            + spacing * 3
        let availableWidth = proposal.width ?? minimumRegularWidth

        if availableWidth >= minimumRegularWidth {
            let identityWidth = availableWidth
                - selectionSize.width
                - iconSize.width
                - metricsSize.width
                - spacing * 3
            let identitySize = subviews[2].sizeThatFits(
                ProposedViewSize(width: identityWidth, height: nil)
            )
            return CGSize(
                width: availableWidth,
                height: max(
                    max(selectionSize.height, iconSize.height),
                    max(identitySize.height, metricsSize.height)
                )
            )
        }

        let columnWidth = max(
            0,
            availableWidth - selectionSize.width - iconSize.width - spacing * 2
        )
        let identitySize = subviews[2].sizeThatFits(
            ProposedViewSize(width: columnWidth, height: nil)
        )
        return CGSize(
            width: availableWidth,
            height: max(
                max(selectionSize.height, iconSize.height),
                identitySize.height + compactSectionSpacing + metricsSize.height
            )
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 4 else { return }
        let selectionSize = subviews[0].sizeThatFits(.unspecified)
        let iconSize = subviews[1].sizeThatFits(.unspecified)
        let metricsSize = subviews[3].sizeThatFits(.unspecified)
        let minimumRegularWidth = selectionSize.width
            + iconSize.width
            + minimumIdentityWidth
            + metricsSize.width
            + spacing * 3

        placeCenteredVertically(
            subviews[0],
            atX: bounds.minX,
            in: bounds,
            size: selectionSize
        )
        let iconX = bounds.minX + selectionSize.width + spacing
        placeCenteredVertically(
            subviews[1],
            atX: iconX,
            in: bounds,
            size: iconSize
        )

        let columnX = iconX + iconSize.width + spacing
        if bounds.width >= minimumRegularWidth {
            let identityWidth = bounds.width
                - selectionSize.width
                - iconSize.width
                - metricsSize.width
                - spacing * 3
            let identitySize = subviews[2].sizeThatFits(
                ProposedViewSize(width: identityWidth, height: nil)
            )
            placeCenteredVertically(
                subviews[2],
                atX: columnX,
                in: bounds,
                size: identitySize,
                proposedWidth: identityWidth
            )
            placeCenteredVertically(
                subviews[3],
                atX: bounds.maxX - metricsSize.width,
                in: bounds,
                size: metricsSize
            )
            return
        }

        let columnWidth = max(0, bounds.maxX - columnX)
        let identitySize = subviews[2].sizeThatFits(
            ProposedViewSize(width: columnWidth, height: nil)
        )
        subviews[2].place(
            at: CGPoint(x: columnX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: columnWidth,
                height: identitySize.height
            )
        )
        subviews[3].place(
            at: CGPoint(
                x: columnX,
                y: bounds.minY + identitySize.height + compactSectionSpacing
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: metricsSize.width,
                height: metricsSize.height
            )
        )
    }

    private func placeCenteredVertically(
        _ subview: LayoutSubview,
        atX x: CGFloat,
        in bounds: CGRect,
        size: CGSize,
        proposedWidth: CGFloat? = nil
    ) {
        subview.place(
            at: CGPoint(x: x, y: bounds.midY - size.height / 2),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: proposedWidth ?? size.width,
                height: size.height
            )
        )
    }
}

private struct WorkoutAnalyticsDraftRowLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let menuSize = subviews[1].sizeThatFits(.unspecified)
        let availableWidth = proposal.width
            ?? subviews[0].sizeThatFits(.unspecified).width + menuSize.width
        let contentWidth = max(0, availableWidth - menuSize.width)
        let contentSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: contentWidth, height: nil)
        )
        return CGSize(
            width: availableWidth,
            height: max(contentSize.height, menuSize.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let menuSize = subviews[1].sizeThatFits(.unspecified)
        let contentWidth = max(0, bounds.width - menuSize.width)
        let contentSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: contentWidth, height: nil)
        )

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(
                width: contentWidth,
                height: contentSize.height
            )
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(
                width: menuSize.width,
                height: menuSize.height
            )
        )
    }
}

public struct WorkoutAnalyticsEntryView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    @Binding private var isPresented: Bool
    @State private var viewModel: WorkoutAnalyticsEntryViewModel
    @State private var showCalendar = false
    @State private var editingExerciseID: UUID?
    private let headerDateFormatter: DateFormatter?
    private let exerciseIconProvider: (Exercise, AppAccentScheme) -> Image

    public init(workout: Workout, isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _viewModel = State(
            initialValue: WorkoutAnalyticsEntryViewModel(workout: workout)
        )
        headerDateFormatter = nil
        exerciseIconProvider = { exercise, scheme in
            Image(scheme.iconName(for: exercise.displayIconName))
        }
    }

    init(
        viewModel: WorkoutAnalyticsEntryViewModel,
        isPresented: Binding<Bool>,
        headerDateFormatter: DateFormatter,
        exerciseIconProvider: @escaping (
            Exercise,
            AppAccentScheme
        ) -> Image
    ) {
        _isPresented = isPresented
        _viewModel = State(initialValue: viewModel)
        self.headerDateFormatter = headerDateFormatter
        self.exerciseIconProvider = exerciseIconProvider
    }

    public var body: some View {
        ZStack {
            pageContent
                .disabled(viewModel.saveState != .editing)

            CalendarDialogView(
                isPresented: $showCalendar,
                selectedDate: $viewModel.selectedDate,
                title: AppText.analyticsWorkoutDateTitle
            )

            if let editingExerciseID,
               let draft = viewModel.draft(for: editingExerciseID) {
                AddAnalyticsEntryView(
                    date: viewModel.selectedDate,
                    exercise: draft.exercise,
                    existingEntry: draft.entry,
                    isPresented: detailPresentationBinding,
                    dateFormatter: headerDateFormatter,
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

    private var pageContent: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                stickyHeader

                ScrollView {
                    scrollableContent
                }
                .scrollIndicators(.hidden)
            }

            SheetActionArea(
                saveLabel: AppText.workoutSave,
                isSaveEnabled: viewModel.canSave,
                backdropColor: .black,
                saveAccessibilityIdentifier: WorkoutAnalyticsIDs.saveButton,
                onCancel: { isPresented = false },
                onSave: saveAndDismiss
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
    }


    private var stickyHeader: some View {
        VStack(alignment: .leading, spacing: AppStyle.Padding.card) {
            header
            dateButton
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, AppStyle.Padding.titleTop)
        .background(AppStyle.Color.backgroundColor)
    }

    private var scrollableContent: some View {
        VStack(alignment: .leading, spacing: AppStyle.Padding.card) {
            selectionHeader

            if viewModel.saveFailed {
                Text(AppText.workoutAnalyticsSaveFailed)
                    .font(AppStyle.Font.detailCaption)
                    .foregroundColor(AppStyle.Color.error)
            }

            if viewModel.drafts.isEmpty {
                emptyState
            } else {
                exerciseList
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, AppStyle.Padding.card)
        .padding(.bottom, Self.actionOverlayClearance)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppStyle.Padding.cardVertical) {
            Text(AppText.workoutLog)
                .font(AppStyle.Font.sheetSectionLabel)
                .foregroundColor(
                    AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel)
                )
                .accessibilityIdentifier(WorkoutAnalyticsIDs.screen)

            Text(verbatim: viewModel.workout.name)
                .font(AppStyle.Font.workoutEntryTitle)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(AppText.workoutReviewAndSave)
                .font(AppStyle.Font.profileSubtitle)
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
            HStack(spacing: AppStyle.Padding.card) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.sheetInputBackground)

                    Image(systemName: "calendar")
                        .font(AppStyle.Font.iconSymbol)
                        .foregroundColor(appColorTheme.accent.glow)
                }
                .frame(
                    width: Self.dateIconContainerSize,
                    height: Self.dateIconContainerSize
                )

                VStack(alignment: .leading, spacing: AppStyle.Padding.cardVertical) {
                    Text(verbatim: formattedHeaderDate)
                    .font(AppStyle.Font.analyticsExerciseTitle)
                    .foregroundColor(AppStyle.Color.white)

                    Text(AppText.exerciseCount(count: viewModel.drafts.count))
                        .font(AppStyle.Font.profileSubtitle)
                        .foregroundColor(
                            AppStyle.Color.white.opacity(
                                AppStyle.Opacity.secondaryLabel
                            )
                        )
                }

                Spacer()
            }
            .padding(.vertical, Self.dateCardVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            dateDivider
        }
        .overlay(alignment: .bottom) {
            dateDivider
        }
        .accessibilityLabel(AppText.analyticsWorkoutDate)
        .accessibilityValue(
            Text(verbatim: formattedAccessibilityDate)
        )
        .accessibilityIdentifier(WorkoutAnalyticsIDs.dateButton)
    }

    private var dateDivider: some View {
        Rectangle()
            .fill(
                AppStyle.Color.white.opacity(
                    AppStyle.Opacity.hairlineDivider
                )
            )
            .frame(height: Self.dateDividerHeight)
    }

    private var selectionHeader: some View {
        Text(AppText.analyticsSelectedExercises(selected: viewModel.selectedCount, total: viewModel.drafts.count))
            .font(AppStyle.Font.sheetSectionLabel)
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Text(AppText.workoutNoActiveExercises)
            .font(AppStyle.Font.defaultFont)
            .foregroundColor(
                AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel)
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, AppStyle.Padding.card)
    }

    private var exerciseList: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.drafts) { draft in
                draftRow(draft)

                if draft.id != viewModel.drafts.last?.id {
                    exerciseRowDivider
                }
            }
        }
    }

    private var exerciseRowDivider: some View {
        Rectangle()
            .fill(
                AppStyle.Color.white.opacity(
                    AppStyle.Opacity.hairlineDivider
                )
            )
            .frame(height: Self.exerciseRowDividerHeight)
    }

    private func draftRow(_ draft: WorkoutAnalyticsExerciseDraft) -> some View {
        WorkoutAnalyticsDraftRowLayout {
            WorkoutAnalyticsDraftContentLayout(
                spacing: Self.exerciseRowContentSpacing,
                minimumIdentityWidth: Self.exerciseNameMinimumWidth,
                compactSectionSpacing: Self.compactRowSectionSpacing
            ) {
                selectionIndicator(isSelected: draft.isSelected)
                selectionIcon(for: draft.exercise)
                exerciseIdentity(draft)
                draftMetrics(draft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Self.exerciseRowVerticalPadding)
            .padding(.leading, Self.exerciseRowHorizontalPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleSelection(for: draft.id)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(draft.exercise.name)
            .accessibilityValue(WorkoutAnalyticsAccessibility.value(for: draft, locale: locale))
            .accessibilityAddTraits(
                draft.isSelected ? [.isButton, .isSelected] : .isButton
            )
            .accessibilityAction {
                toggleSelection(for: draft.id)
            }
            .accessibilityIdentifier(
                WorkoutAnalyticsIDs.exerciseSelection(draft.id)
            )

            Button {
                editingExerciseID = draft.id
            } label: {
                VStack(spacing: Self.exerciseMenuDotSpacing) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(
                                AppStyle.Color.white.opacity(
                                    AppStyle.Opacity.secondaryLabel
                                )
                            )
                            .frame(
                                width: Self.exerciseMenuDotSize,
                                height: Self.exerciseMenuDotSize
                            )
                    }
                }
                .frame(
                    width: AppStyle.Layout.minimumTapTargetSize,
                    height: AppStyle.Layout.minimumTapTargetSize
                )
                .padding(.trailing, Self.exerciseRowHorizontalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.exerciseDetailsAccessibility(name: draft.exercise.name))
            .accessibilityIdentifier(
                WorkoutAnalyticsIDs.exerciseDetails(draft.id)
            )
            .fixedSize()
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseIdentity(
        _ draft: WorkoutAnalyticsExerciseDraft
    ) -> some View {
        VStack(alignment: .leading, spacing: Self.exerciseTextSpacing) {
            Text(verbatim: draft.exercise.name)
                .font(AppStyle.Font.analyticsExerciseData)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(draft.exercise.category.localizedName)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(
                    AppStyle.Color.white.opacity(
                        AppStyle.Opacity.secondaryLabel
                    )
                )
        }
    }

    private func draftMetrics(
        _ draft: WorkoutAnalyticsExerciseDraft
    ) -> some View {
        HStack(spacing: 0) {
            if draft.exercise.hasWeight {
                weightMetric(value: weightValue(for: draft))
            } else {
                Color.clear
                    .frame(width: Self.exerciseWeightMetricWidth)
                    .accessibilityHidden(true)
            }

            metricColumn(
                value: "\(draft.setCount)",
                label: AppText.exerciseSetLabel(count: draft.setCount)
            )
            metricColumn(
                value: repsValue(for: draft),
                label: AppText.exerciseRepsLowercase
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func weightMetric(value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.weightUnitSpacing) {
            Text(verbatim: value)
                .font(AppStyle.Font.sectionTitle)
                .foregroundColor(appColorTheme.accent.glow)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(AppText.unitKilogram)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(
                    AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel)
                )
        }
        .frame(width: Self.exerciseWeightMetricWidth)
    }

    private func metricColumn(
        value: String,
        label: LocalizedStringResource
    ) -> some View {
        VStack(spacing: Self.exerciseTextSpacing) {
            Text(verbatim: value)
                .font(AppStyle.Font.sectionTitle)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(
                    AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: Self.exerciseMetricWidth)
    }

    private func weightValue(
        for draft: WorkoutAnalyticsExerciseDraft
    ) -> String {
        let weights = Set(draft.entry.setProgress.map(\.weight))
        guard weights.count == 1, let weight = weights.first else {
            return AppText.resolve(AppText.commonVariable, locale: locale)
        }
        return WeightFormatter.format(weight, locale: locale)
    }

    private func repsValue(
        for draft: WorkoutAnalyticsExerciseDraft
    ) -> String {
        let reps = Set(draft.entry.setProgress.map(\.currentReps))
        guard reps.count == 1, let value = reps.first else {
            return AppText.resolve(AppText.commonVariable, locale: locale)
        }
        return value.formatted(.number.locale(locale))
    }

    private func selectionIcon(
        for exercise: Exercise
    ) -> some View {
        exerciseIconProvider(exercise, appColorTheme.scheme)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(
                width: Self.exerciseIconSize,
                height: Self.exerciseIconSize,
                alignment: exercise.iconAlignment
            )
            .clipped()
            .frame(
                width: Self.exerciseIconSize,
                height: Self.exerciseIconSize
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
                    .fill(appColorTheme.accent.glow)
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

    private var formattedHeaderDate: String {
        headerDateFormatter?.string(from: viewModel.selectedDate)
            ?? viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(locale))
    }

    private var formattedAccessibilityDate: String {
        viewModel.selectedDate.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    private static let dateIconContainerSize: CGFloat = 44
    private static let dateCardVerticalPadding: CGFloat = 16
    private static let dateDividerHeight: CGFloat = 0.5
    private static let actionOverlayClearance: CGFloat = 84
    private static let exerciseIconSize: CGFloat = 44
    private static let exerciseWeightMetricWidth: CGFloat = 52
    private static let exerciseMetricWidth: CGFloat = 34
    private static let exerciseNameMinimumWidth: CGFloat = 72
    private static let exerciseRowContentSpacing: CGFloat = 4
    private static let exerciseRowHorizontalPadding: CGFloat = 8
    private static let exerciseRowVerticalPadding: CGFloat = 10
    private static let exerciseTextSpacing: CGFloat = 4
    private static let compactRowSectionSpacing: CGFloat = 8
    private static let exerciseMenuDotSize: CGFloat = 3
    private static let exerciseMenuDotSpacing: CGFloat = 3
    private static let weightUnitSpacing: CGFloat = 3
    private static let exerciseRowDividerHeight: CGFloat = 0.5

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

    private func toggleSelection(for exerciseID: UUID) {
        guard viewModel.saveState == .editing else { return }
        viewModel.toggleSelection(for: exerciseID)
    }
}
