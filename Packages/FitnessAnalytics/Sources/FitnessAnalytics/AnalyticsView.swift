import FitnessCore
import FitnessResources
import FitnessUI
import SwiftUI

public struct AnalyticsView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    @State private var exercise: Exercise
    public var viewModel: AnalyticsViewModel
    @State private var analyticsRevision: ExerciseAnalyticsCacheRevision
    private let initialReps: Int
    @State private var selectedDate: Date
    @State private var showCalendarDialog: Bool = false

    @State private var showAddDataSheet: Bool = false
    @State private var editingEntry: AnalyticsEntry?
    @State private var showGoalSheet: Bool = false
    @State private var tempGoal: String = ""

    public init(exercise: Exercise, viewModel: AnalyticsViewModel, initialDate: Date = Date()) {
        let latestExercise = viewModel.resolveLatestExercise(exercise)
        self._exercise = State(initialValue: latestExercise)
        self.viewModel = viewModel
        self._analyticsRevision = State(
            initialValue: viewModel.revisionSource(for: exercise.id)
        )
        self.initialReps = latestExercise.reps
        self._selectedDate = State(initialValue: initialDate)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry: geometry)
                CalendarDialogView(
                    isPresented: $showCalendarDialog,
                    selectedDate: $selectedDate,
                    highlightedDates: cachedEntries.map(\.date),
                    title: AppText.analyticsMonthlyTraining
                )
                addDataOverlay
                goalSetterOverlay
            }
        }
        .accessibilityIdentifier(AnalyticsIDs.screen)
    }

    private func mainContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView

                progressChartView
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.vertical, 12)

                weightMilestoneView
                resultsView
                Spacer()
            }
            .frame(minHeight: geometry.size.height)
        }
        .background(AppStyle.Color.backgroundColor)
        .presentationDragIndicator(.visible)
        .onAppear {
            viewModel.reloadEntries(for: exercise.id)
        }
    }

    private var progressChartView: some View {
        VStack(spacing: 8) {
            hillChartView
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var hillChartView: some View {
        VStack(spacing: 0) {
            HStack {
                Group {
                    if exercise.hasWeight {
                        Text(verbatim: "KG")
                    } else {
                        Text(AppText.exerciseReps)
                    }
                }
                .font(AppStyle.Font.analyticsAxis)
                .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            GeometryReader { geometry in
                let points = chartPoints(geometry: geometry)
                ZStack {
                    chartGridLines(geometry: geometry)
                    hillShapeView(points: points, geometry: geometry)
                    hillOutlineView(points: points, geometry: geometry)
                    milestonesView(points: points, geometry: geometry)
                }
            }
            .frame(height: 105)
            HStack {
                Spacer()
                Text(AppText.commonDate)
                    .font(AppStyle.Font.analyticsAxis)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private func chartGridLines(geometry: GeometryProxy) -> some View {
        let midY = geometry.size.height / 2
        return Path { path in
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
        }
        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
    }

    private func chartPoints(geometry: GeometryProxy) -> [ProgressChartCalculator.ChartPoint] {
        let entries = cachedEntries
        let milestones = exercise.hasWeight
            ? viewModel.getDailyWeightProgression(from: entries)
            : viewModel.getDailyRepsProgression(from: entries)
        return ProgressChartCalculator.calculateDynamicMilestones(
            milestones: milestones,
            geometry: geometry
        )
    }

    private func hillShapeView(
        points: [ProgressChartCalculator.ChartPoint],
        geometry: GeometryProxy
    ) -> some View {
        return ProgressChartCalculator.generateCurvePathForFill(
            chartPoints: points,
            geometry: geometry
        )
        .fill(
            LinearGradient(
                gradient: Gradient(colors: [
                    appColorTheme.accent.glow.opacity(0.15),
                    appColorTheme.accent.glow.opacity(0.02)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func hillOutlineView(
        points: [ProgressChartCalculator.ChartPoint],
        geometry: GeometryProxy
    ) -> some View {
        return ProgressChartCalculator.generateCurvePath(
            chartPoints: points,
            geometry: geometry
        )
        .stroke(appColorTheme.accent.glow, lineWidth: 2)
        .shadow(color: appColorTheme.accent.glow.opacity(0.4), radius: 3, x: 0, y: 0)
    }

    private func milestonesView(
        points: [ProgressChartCalculator.ChartPoint],
        geometry: GeometryProxy
    ) -> some View {
        return ForEach(points) { point in
            dynamicMilestonePointView(point: point, geometry: geometry)
        }
    }

    private func dynamicMilestonePointView(point: ProgressChartCalculator.ChartPoint, geometry: GeometryProxy) -> some View {
        let weightText = WeightFormatter.format(point.weight, locale: locale)

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.xPosition, y: point.yPosition + 8))
                path.addLine(to: CGPoint(x: point.xPosition, y: geometry.size.height - 12))
            }
            .stroke(appColorTheme.accent.glow.opacity(point.isCurrentWeight ? 0.8 : 0.4),
                   style: StrokeStyle(lineWidth: point.isCurrentWeight ? 2 : 1, dash: [4, 4]))

            Circle()
                .fill(appColorTheme.accent.glow)
                .frame(width: point.isCurrentWeight ? 10 : 6, height: point.isCurrentWeight ? 10 : 6)
                .position(x: point.xPosition, y: point.yPosition)
                .shadow(color: appColorTheme.accent.glow.opacity(0.7), radius: point.isCurrentWeight ? 6 : 3, x: 0, y: 0)

            Text(verbatim: weightText)
                .font(point.isCurrentWeight ? AppStyle.Font.cardValueBold : AppStyle.Font.cardSmallMedium)
                .foregroundColor(appColorTheme.accent.glow)
                .position(x: point.xPosition, y: point.yPosition - (point.isCurrentWeight ? 15 : 12))

            if let date = point.date {
                Text(verbatim: date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(locale)))
                    .font(AppStyle.Font.analyticsAxis)
                    .foregroundColor(.white.opacity(0.5))
                    .position(x: point.xPosition, y: geometry.size.height + 2)
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(verbatim: exercise.name)
                .font(AppStyle.Font.analyticsExerciseTitle)
                .foregroundColor(AppStyle.Color.white)
                .fixedSize()

            Spacer()

            Button(action: {
                showCalendarDialog = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(AppStyle.Font.detailExercise)
                    Text(verbatim: selectedDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits).locale(locale)))
                        .font(AppStyle.Font.detailExercise)
                }
                .foregroundColor(appColorTheme.accent.glow)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var entriesForSelectedDate: [AnalyticsEntry] {
        let calendar = Calendar.current
        return cachedEntries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: selectedDate)
        }
    }

    private var cachedEntries: [AnalyticsEntry] {
        // Register only this Exercise's cache token with SwiftUI. The cache
        // payload itself is intentionally ObservationIgnored so unrelated
        // histories cannot invalidate this detail screen.
        _ = analyticsRevision.value
        return viewModel.cachedEntries(for: exercise.id) ?? []
    }

    @ViewBuilder
    private var resultsView: some View {
        let entries = entriesForSelectedDate

        if entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppText.commonNoDataAvailable)
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.horizontal, AppStyle.Padding.horizontal)

                HStack(alignment: .top, spacing: 8) {
                    Button(action: {
                        showAddDataSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(AppStyle.Font.analyticsHeadline)
                            Text(AppText.analyticsAddData)
                                .font(.body)
                                .fontWeight(.bold)
                                .accessibilityIdentifier(
                                    FitnessCore.AnalyticsIDs.addDataButton
                                )
                        }
                        .foregroundColor(appColorTheme.accent.glow)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(height: 75)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                    .accessibilityIdentifier(FitnessCore.AnalyticsIDs.addDataButton)

                    Spacer()
                        .frame(maxWidth: .infinity)
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
            }
        } else {
            VStack(alignment: .leading, spacing: 11) {
                Text(AppText.commonResultsToday)
                    .font(AppStyle.Font.analyticsExerciseData)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                ForEach(entries.reversed()) { entry in
                    entryView(entry)
                }
            }
            .padding(.vertical, 10)
            .padding(.top, 5)
            .background(AppStyle.Color.backgroundColor)
        }
    }

    private func entryView(_ entry: AnalyticsEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let groups = BilateralSetGrouping.groups(for: entry.setProgress) {
                List {
                    ForEach(groups) { group in
                        bilateralSetRowView(entry: entry, group: group)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    viewModel.deleteLogicalSetFromEntry(
                                        exerciseId: exercise.id,
                                        entryId: entry.id,
                                        logicalSetIndex: group.logicalSetIndex
                                    )
                                } label: {
                                    Label(AppText.actionDelete, systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollDisabled(true)
                .frame(
                    height: CGFloat(groups.count)
                        * AppStyle.Layout.bilateralAnalyticsRowHeight
                )
                .background(Color.clear)
            } else {
                List {
                    ForEach(Array(entry.setProgress.enumerated()), id: \.element.id) { index, progress in
                        setRowView(entry: entry, index: index, progress: progress)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    viewModel.deleteSetFromEntry(
                                        exerciseId: exercise.id,
                                        entryId: entry.id,
                                        setIndex: index
                                    )
                                } label: {
                                    Label(AppText.actionDelete, systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollDisabled(true)
                .frame(height: CGFloat(entry.setProgress.count * 90))
                .background(Color.clear)
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }

    private func bilateralSetRowView(
        entry: AnalyticsEntry,
        group: BilateralSetGroup
    ) -> some View {
        Button {
            editingEntry = entry
            showAddDataSheet = true
        } label: {
            VStack(alignment: .leading, spacing: AppStyle.Padding.cardVertical) {
                Text(AppText.exerciseSetNumber(number: group.logicalSetIndex + 1))
                    .font(AppStyle.Font.sectionHeadline)
                    .foregroundColor(AppStyle.Color.white)

                HStack(spacing: AppStyle.Padding.card) {
                    bilateralResult(side: .left, progress: group.left)
                    bilateralResult(side: .right, progress: group.right)
                }
            }
            .padding(AppStyle.Padding.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                    .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                            .stroke(
                                AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.top, AppStyle.Padding.titleTop)
        }
        .buttonStyle(.plain)
    }

    private func bilateralResult(
        side: ExerciseSide,
        progress: SetProgress
    ) -> some View {
        VStack(alignment: .leading, spacing: AppStyle.Layout.bilateralColumnSpacing) {
            Text(side == .left ? AppText.accessibilityLeft : AppText.accessibilityRight)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(appColorTheme.accent.glow)

            HStack(spacing: AppStyle.Layout.bilateralColumnSpacing) {
                if exercise.hasWeight {
                    Text(verbatim: "\(WeightFormatter.format(progress.weight, locale: locale)) kg")
                        .font(AppStyle.Font.sectionHeadline)
                        .foregroundColor(appColorTheme.accent.glow)
                        .lineLimit(1)
                        .minimumScaleFactor(
                            AppStyle.Layout.bilateralAnalyticsMinimumScaleFactor
                        )
                }

                Text(verbatim: "\(progress.currentReps) / \(initialReps)")
                    .font(AppStyle.Font.detailExercise)
                    .foregroundColor(AppStyle.Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(
                        AppStyle.Layout.bilateralAnalyticsMinimumScaleFactor
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(
            AnalyticsIDs.bilateralResult(
                logicalSet: progress.logicalSetIndex ?? 0,
                side: side
            )
        )
    }

    private func setRowView(entry: AnalyticsEntry, index: Int, progress: SetProgress) -> some View {
        Button {
            editingEntry = entry
            showAddDataSheet = true
        } label: {
            HStack {
                Text(AppText.liveActivitySet)
                    .font(AppStyle.Font.numberPadSymbol)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if exercise.hasWeight {
                    Text(verbatim: WeightFormatter.format(progress.weight, locale: locale))
                        .font(AppStyle.Font.analyticsBigNumber)
                        .foregroundColor(appColorTheme.accent.glow)

                    Text(verbatim: "kg")
                        .font(AppStyle.Font.analyticsBigNumber)
                        .foregroundColor(appColorTheme.accent.primary)
                }

                Text(verbatim: "\(progress.currentReps) / \(initialReps)")
                    .font(AppStyle.Font.numberPadSymbol)
                    .foregroundColor(AppStyle.Color.white)
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.top, 9)
        }
        .buttonStyle(.plain)
    }

    private var addDataOverlay: some View {
        Group {
            if showAddDataSheet {
                AddAnalyticsEntryView(
                    date: selectedDate,
                    exercise: exercise,
                    existingEntry: editingEntry,
                    isPresented: $showAddDataSheet,
                    onSave: { newEntry in
                        viewModel.saveOrReplaceAnalyticsEntry(
                            exerciseId: exercise.id,
                            setProgress: newEntry.setProgress,
                            date: selectedDate
                        )
                        editingEntry = nil
                    },
                    onCancel: {
                        editingEntry = nil
                    }
                )
            }
        }
    }

    private var goalSetterOverlay: some View {
        Group {
            if showGoalSheet {
                ZStack {
                    goalSheetBackground
                    goalSheetContent
                }
                .transition(.opacity)
            }
        }
    }

    private var goalSheetBackground: some View {
        Color.black.opacity(0.5)
            .contentShape(Rectangle())
            .onTapGesture {
                showGoalSheet = false
            }
    }

    private var goalSheetContent: some View {
        VStack {
            Spacer()
            goalSheetModal
            Spacer()
        }
    }

    private var goalSheetModal: some View {
        VStack(spacing: 16) {
            goalSheetHeader
            goalInputField
            goalActionButtons
        }
        .padding(.horizontal, 24)
        .background(AppStyle.Color.exerciseCardBackground)
        .cornerRadius(16)
        .padding(.horizontal, 32)
    }

    private var goalSheetHeader: some View {
        Text(exercise.hasWeight ? AppText.analyticsSetWeightGoal : AppText.analyticsSetRepsGoal)
            .font(.headline)
            .foregroundColor(AppStyle.Color.white)
            .padding(.top, 16)
    }

    private var goalInputField: some View {
        ZStack(alignment: .trailing) {
            goalTextField
            goalClearButton
        }
    }

    private var goalTextField: some View {
        ZStack(alignment: .leading) {
            Group {
                #if os(iOS)
                TextField("", text: $tempGoal)
                    .keyboardType(.decimalPad)
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .padding()
                    .padding(.trailing, exercise.goal != nil ? 40 : 0)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                #else
                TextField("", text: $tempGoal)
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .padding()
                    .padding(.trailing, exercise.goal != nil ? 40 : 0)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                #endif
            }

            goalPlaceholder
        }
    }

    private var goalPlaceholder: some View {
        Group {
            if tempGoal.isEmpty {
                Text(exercise.hasWeight ? AppText.analyticsEnterGoalWeight : AppText.analyticsEnterGoalReps)
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.leading, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var goalClearButton: some View {
        Group {
            if exercise.goal != nil && !tempGoal.isEmpty {
                Button(action: {
                    tempGoal = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppStyle.Color.gray)
                        .font(AppStyle.Font.analyticsExerciseTitle)
                }
                .padding(.trailing, 12)
            }
        }
    }

    private var goalActionButtons: some View {
        HStack(spacing: 16) {
            goalCancelButton
            goalSaveButton
        }
        .padding(.bottom, 16)
    }

    private var goalCancelButton: some View {
        Button(AppText.actionCancel) {
            showGoalSheet = false
        }
        .font(.body)
        .foregroundColor(AppStyle.Color.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }

    private var goalSaveButton: some View {
        Button(AppText.actionSave) {
            saveGoal()
        }
        .font(.body)
        .foregroundColor(AppStyle.Color.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(appColorTheme.accent.primary)
        .cornerRadius(12)
    }

    private func saveGoal() {
        viewModel.saveGoal(for: &exercise, goalText: tempGoal)
        showGoalSheet = false
    }

    private func formatGoalForInput(_ goal: Double) -> String {
        return WeightFormatter.formatGoalForInput(goal, locale: locale)
    }

    private var goalTileNumber: String {
        if let goal = exercise.goal {
            return WeightFormatter.format(goal, locale: locale)
        }
        return AppText.resolve(AppText.analyticsSetGoal, locale: locale)
    }

    private var weightMilestoneView: some View {
        let entries = cachedEntries

        return VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: {
                    tempGoal = exercise.goal.map(formatGoalForInput) ?? ""
                    showGoalSheet = true
                }) {
                    VStack(spacing: 4) {
                        Text(goalTileNumber)
                            .font(AppStyle.Font.analyticsBigNumber)
                            .foregroundColor(appColorTheme.accent.glow)

                        Text(exercise.hasWeight ? AppText.analyticsGoalWeight : AppText.analyticsGoalReps)
                            .font(AppStyle.Font.chartAxisSmall)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(8)
                    .frame(height: 85)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Color.clear.frame(maxWidth: .infinity).frame(height: 85)
                Color.clear.frame(maxWidth: .infinity).frame(height: 85)
                Color.clear.frame(maxWidth: .infinity).frame(height: 85)
            }

            HStack(alignment: .top, spacing: 8) {
                AnalyticsTileNumberView(
                    number: exercise.hasWeight
                        ? "\(viewModel.totalWeightIncreases(from: entries))"
                        : "\(viewModel.totalRepsIncreases(from: entries))",
                    label: AppText.resolve(
                        exercise.hasWeight ? AppText.analyticsWeightIncrease : AppText.analyticsRepsIncrease,
                        locale: locale
                    )
                )

                AnalyticsTileNumberView(
                    number: "\(viewModel.trainingDaysInCurrentMonth(from: entries))",
                    label: AppText.resolve(
                        AppText.analyticsTrainingMonth(month:
                            Date().formatted(.dateTime.month(.wide).locale(locale))
                        ),
                        locale: locale
                    )
                )

                AnalyticsTileNumberView(
                    number: exercise.hasWeight
                        ? "\(viewModel.trainingSessionsUntilWeightIncrease(from: entries))"
                        : "\(viewModel.trainingSessionsUntilRepsIncrease(from: entries))",
                    label: AppText.resolve(
                        exercise.hasWeight
                            ? AppText.analyticsTrainingToIncreaseWeight
                            : AppText.analyticsTrainingToIncreaseReps,
                        locale: locale
                    )
                )

                AnalyticsTileNumberView(
                    number: "\(entries.count)",
                    label: AppText.resolve(AppText.analyticsTotalTraining, locale: locale)
                )
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 8)
    }
}
