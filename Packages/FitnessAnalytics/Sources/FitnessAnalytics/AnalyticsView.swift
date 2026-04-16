import FitnessCore
import FitnessUI
import SwiftUI

public struct AnalyticsView: View {
    @State private var exercise: Exercise
    public var viewModel: AnalyticsViewModel
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
                    highlightedDates: viewModel.loadAnalyticsDates(for: exercise.id),
                    title: "Monthly training"
                )
                addDataOverlay
                goalSetterOverlay
            }
        }
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
                Text(exercise.hasWeight ? "KG" : "Reps")
                    .font(AppStyle.Font.analyticsAxis)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            GeometryReader { geometry in
                ZStack {
                    chartGridLines(geometry: geometry)
                    hillShapeView(geometry: geometry)
                    hillOutlineView(geometry: geometry)
                    milestonesView(geometry: geometry)
                }
            }
            .frame(height: 105)
            HStack {
                Spacer()
                Text("Date")
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
        let milestones = exercise.hasWeight
            ? viewModel.getDailyWeightProgression(for: exercise.id)
            : viewModel.getDailyRepsProgression(for: exercise.id)
        return ProgressChartCalculator.calculateDynamicMilestones(
            milestones: milestones,
            geometry: geometry
        )
    }

    private func hillShapeView(geometry: GeometryProxy) -> some View {
        let points = chartPoints(geometry: geometry)
        return ProgressChartCalculator.generateCurvePathForFill(
            chartPoints: points,
            geometry: geometry
        )
        .fill(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppStyle.Color.greenGlow.opacity(0.15),
                    AppStyle.Color.greenGlow.opacity(0.02)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func hillOutlineView(geometry: GeometryProxy) -> some View {
        let points = chartPoints(geometry: geometry)
        return ProgressChartCalculator.generateCurvePath(
            chartPoints: points,
            geometry: geometry
        )
        .stroke(AppStyle.Color.greenGlow, lineWidth: 2)
        .shadow(color: AppStyle.Color.greenGlow.opacity(0.4), radius: 3, x: 0, y: 0)
    }

    private func milestonesView(geometry: GeometryProxy) -> some View {
        let points = chartPoints(geometry: geometry)
        return ForEach(Array(points.enumerated()), id: \.offset) { index, point in
            dynamicMilestonePointView(point: point, geometry: geometry)
        }
    }

    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return f
    }()

    private func dynamicMilestonePointView(point: ProgressChartCalculator.ChartPoint, geometry: GeometryProxy) -> some View {
        let weightText = WeightFormatter.format(point.weight)

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.xPosition, y: point.yPosition + 8))
                path.addLine(to: CGPoint(x: point.xPosition, y: geometry.size.height - 12))
            }
            .stroke(AppStyle.Color.greenGlow.opacity(point.isCurrentWeight ? 0.8 : 0.4),
                   style: StrokeStyle(lineWidth: point.isCurrentWeight ? 2 : 1, dash: [4, 4]))

            Circle()
                .fill(AppStyle.Color.greenGlow)
                .frame(width: point.isCurrentWeight ? 10 : 6, height: point.isCurrentWeight ? 10 : 6)
                .position(x: point.xPosition, y: point.yPosition)
                .shadow(color: AppStyle.Color.greenGlow.opacity(0.7), radius: point.isCurrentWeight ? 6 : 3, x: 0, y: 0)

            Text(weightText)
                .font(point.isCurrentWeight ? AppStyle.Font.cardValueBold : AppStyle.Font.cardSmallMedium)
                .foregroundColor(AppStyle.Color.greenGlow)
                .position(x: point.xPosition, y: point.yPosition - (point.isCurrentWeight ? 15 : 12))

            if let date = point.date {
                Text(Self.chartDateFormatter.string(from: date))
                    .font(AppStyle.Font.analyticsAxis)
                    .foregroundColor(.white.opacity(0.5))
                    .position(x: point.xPosition, y: geometry.size.height + 2)
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(exercise.name)
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
                    Text(DateFormatter.germanShort.string(from: selectedDate))
                        .font(AppStyle.Font.detailExercise)
                }
                .foregroundColor(AppStyle.Color.greenGlow)
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
        return viewModel.entries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: selectedDate)
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        let entries = entriesForSelectedDate

        if entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("No data available")
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
                            Text("Add data")
                                .font(.body)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(AppStyle.Color.greenGlow)
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

                    Spacer()
                        .frame(maxWidth: .infinity)
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
            }
        } else {
            VStack(alignment: .leading, spacing: 11) {
                Text("Results today")
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
                                Label("Delete", systemImage: "trash")
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
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }

    private func setRowView(entry: AnalyticsEntry, index: Int, progress: SetProgress) -> some View {
        Button {
            editingEntry = entry
            showAddDataSheet = true
        } label: {
            HStack {
                Text("Set")
                    .font(AppStyle.Font.numberPadSymbol)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if exercise.hasWeight {
                    Text(WeightFormatter.format(progress.weight))
                        .font(AppStyle.Font.analyticsBigNumber)
                        .foregroundColor(AppStyle.Color.greenGlow)

                    Text("kg")
                        .font(AppStyle.Font.analyticsBigNumber)
                        .foregroundColor(AppStyle.Color.green)
                }

                Text("\(progress.currentReps) / \(initialReps)")
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
        Text(exercise.hasWeight ? "Set Weight Goal" : "Set Reps Goal")
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
                Text(exercise.hasWeight ? "Enter goal weight" : "Enter goal reps")
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
        Button("Cancel") {
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
        Button("Save") {
            saveGoal()
        }
        .font(.body)
        .foregroundColor(AppStyle.Color.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(AppStyle.Color.green)
        .cornerRadius(12)
    }

    private func saveGoal() {
        viewModel.saveGoal(for: &exercise, goalText: tempGoal)
        showGoalSheet = false
    }

    private func formatGoalForInput(_ goal: Double) -> String {
        return WeightFormatter.formatGoalForInput(goal)
    }

    private var goalTileNumber: String {
        if let goal = exercise.goal {
            return WeightFormatter.format(goal)
        }
        return "Set"
    }

    private var weightMilestoneView: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: {
                    tempGoal = exercise.goal != nil ? formatGoalForInput(exercise.goal!) : ""
                    showGoalSheet = true
                }) {
                    VStack(spacing: 4) {
                        Text(goalTileNumber)
                            .font(AppStyle.Font.analyticsBigNumber)
                            .foregroundColor(AppStyle.Color.greenGlow)

                        Text(exercise.hasWeight ? "Goal kg" : "Goal Reps")
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
                        ? "\(viewModel.totalWeightIncreases(for: exercise.id))"
                        : "\(viewModel.totalRepsIncreases(for: exercise.id))",
                    label: exercise.hasWeight ? "Weight increase" : "Reps increase"
                )

                AnalyticsTileNumberView(
                    number: "\(viewModel.trainingDaysInCurrentMonth(for: exercise.id))",
                    label: "Training \(viewModel.currentMonthName())"
                )

                AnalyticsTileNumberView(
                    number: exercise.hasWeight
                        ? "\(viewModel.trainingSessionsUntilWeightIncrease(for: exercise.id))"
                        : "\(viewModel.trainingSessionsUntilRepsIncrease(for: exercise.id))",
                    label: exercise.hasWeight ? "Training to increase kg" : "Training to increase Reps"
                )

                AnalyticsTileNumberView(
                    number: "\(viewModel.loadAnalytics(for: exercise.id).count)",
                    label: "Total training"
                )
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 8)
    }
}
