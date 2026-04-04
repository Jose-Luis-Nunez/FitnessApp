import SwiftUI

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AnalyticsView: View {
    @State private var exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    private let initialReps: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var originalDate: Date = Date()
    @State private var tempDate: Date = Date()
    @State private var showCalendarDialog: Bool = false

    @State private var milestoneHeight: CGFloat = 0
    @State private var datesWithData: Set<Date> = []
    @State private var showAddDataSheet: Bool = false
    @State private var editingEntry: AnalyticsEntry?
    @State private var showGoalSheet: Bool = false
    @State private var tempGoal: String = ""
    
    private let paddingAmount: CGFloat = 16
    
    init(exercise: Exercise, viewModel: AnalyticsViewModel) {
        let storageService = ExerciseStorageService()
        let category = exercise.category
        let workoutId = WorkoutStorageService.shared.currentWorkout?.id ?? UUID()
        let exercises = storageService.loadForWorkout(workoutId: workoutId, category: category)
        let latestExercise = exercises.first(where: { $0.id == exercise.id }) ?? exercise
        
        self._exercise = State(initialValue: latestExercise)
        self.viewModel = viewModel
        self.initialReps = latestExercise.reps
    }
    
    var body: some View {
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
    
    private var trainingDates: Set<Date> {
        let allEntries = viewModel.loadAnalytics(for: exercise.id)
        let calendar = Calendar.current
        return Set(allEntries.map { calendar.startOfDay(for: $0.date) })
    }
    
    private func mainContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Top bar with close button and drag indicator
                ZStack {
                    // Drag indicator - centered on screen
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppStyle.Color.gray.opacity(0.4))
                            .frame(width: 36, height: 5)
                        Spacer()
                    }
                    
                    // Close button - positioned on left
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(AppStyle.Color.gray.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(AppStyle.Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppStyle.Color.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                }
                .padding(.top, 16)
                .padding(.leading, 16)
                .padding(.trailing, AppStyle.Padding.horizontal)
                
                headerView
                
                // Progress Chart - always shown
                progressChartView
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.vertical, 12)
                
                weightMilestoneView
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ViewHeightKey.self, value: proxy.size.height)
                        }
                    )
                resultsView
                Spacer()
            }
            .frame(minHeight: geometry.size.height)
            .onPreferenceChange(ViewHeightKey.self) { height in
                milestoneHeight = height
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .standardToolbar(title: "Analytics")
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe down to close (drag distance > 100 and mostly downward)
                    if value.translation.height > 100 && abs(value.translation.width) < abs(value.translation.height) {
                        // This would typically dismiss the view - depends on how it's presented
                        // For now, we'll just add the visual indicator
                    }
                }
        )
        .onAppear {
            originalDate = selectedDate
            datesWithData = viewModel.allDatesWithData(for: exercise.id)
        }
    }
    
    private var progressChartView: some View {
        VStack(spacing: 8) {
            hillChartView
            chartLabelsView
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
        GeometryReader { geometry in
            ZStack {
                hillShapeView(geometry: geometry)
                hillOutlineView(geometry: geometry)
                milestonesView(geometry: geometry)
            }
        }
        .frame(height: 90)
    }
    
    private func hillShapeView(geometry: GeometryProxy) -> some View {
        let milestones = viewModel.getDailyWeightProgression(for: exercise.id)
        let currentWeight = viewModel.loadAnalytics(for: exercise.id, on: selectedDate).first?.setProgress.first?.weight ?? exercise.weight
        
        let chartPoints = ProgressChartCalculator.calculateDynamicMilestones(
            milestones: milestones,
            currentWeight: currentWeight,
            geometry: geometry
        )
        
        return ProgressChartCalculator.generateCurvePathForFill(
            chartPoints: chartPoints,
            geometry: geometry
        )
        .fill(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppStyle.Color.greenGlow.opacity(0.3),
                    AppStyle.Color.greenGlow.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func hillOutlineView(geometry: GeometryProxy) -> some View {
        let milestones = viewModel.getDailyWeightProgression(for: exercise.id)
        let currentWeight = viewModel.loadAnalytics(for: exercise.id, on: selectedDate).first?.setProgress.first?.weight ?? exercise.weight
        
        let chartPoints = ProgressChartCalculator.calculateDynamicMilestones(
            milestones: milestones,
            currentWeight: currentWeight,
            geometry: geometry
        )
        
        return ProgressChartCalculator.generateCurvePath(
            chartPoints: chartPoints,
            geometry: geometry
        )
        .stroke(AppStyle.Color.greenGlow, lineWidth: 3)
        .shadow(color: AppStyle.Color.greenGlow.opacity(0.5), radius: 4, x: 0, y: 0)
    }
    
    private func milestonesView(geometry: GeometryProxy) -> some View {
        let milestones = viewModel.getDailyWeightProgression(for: exercise.id)
        let currentWeight = viewModel.loadAnalytics(for: exercise.id, on: selectedDate).first?.setProgress.first?.weight ?? exercise.weight
        
        let chartPoints = ProgressChartCalculator.calculateDynamicMilestones(
            milestones: milestones,
            currentWeight: currentWeight,
            geometry: geometry
        )
        
        return ForEach(Array(chartPoints.enumerated()), id: \.offset) { index, point in
            dynamicMilestonePointView(point: point, geometry: geometry)
        }
    }
    
    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return f
    }()

    private func dynamicMilestonePointView(point: ProgressChartCalculator.ChartPoint, geometry: GeometryProxy) -> some View {
        let weightText = point.weight == floor(point.weight) ? "\(Int(point.weight))" : String(point.weight).replacingOccurrences(of: ".", with: ",")

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.xPosition, y: point.yPosition + 8))
                path.addLine(to: CGPoint(x: point.xPosition, y: geometry.size.height))
            }
            .stroke(AppStyle.Color.greenGlow.opacity(point.isCurrentWeight ? 0.8 : 0.4),
                   style: StrokeStyle(lineWidth: point.isCurrentWeight ? 2 : 1, dash: [4, 4]))

            Circle()
                .fill(AppStyle.Color.greenGlow)
                .frame(width: point.isCurrentWeight ? 10 : 6, height: point.isCurrentWeight ? 10 : 6)
                .position(x: point.xPosition, y: point.yPosition)
                .shadow(color: AppStyle.Color.greenGlow.opacity(0.7), radius: point.isCurrentWeight ? 6 : 3, x: 0, y: 0)

            Text("\(weightText) KG")
                .font(.system(size: point.isCurrentWeight ? 16 : 11, weight: .bold))
                .foregroundColor(AppStyle.Color.greenGlow)
                .position(x: point.xPosition, y: point.yPosition - (point.isCurrentWeight ? 15 : 12))

            if let date = point.date {
                Text(Self.chartDateFormatter.string(from: date))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .position(x: point.xPosition, y: geometry.size.height - 2)
            }
        }
    }
    
    private var chartLabelsView: some View {
        EmptyView()
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
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                    Text(DateFormatter.germanShort.string(from: selectedDate))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppStyle.Color.greenGlow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, 15)
        .padding(.bottom, 10)
    }
    
    private var resultsView: some View {
        let entries = viewModel.loadAnalytics(for: exercise.id, on: selectedDate)
        
        if entries.isEmpty {
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    Text("No data available")
                        .font(AppStyle.Font.defaultFont)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.horizontal, AppStyle.Padding.horizontal)
                    
                    HStack(alignment: .top, spacing: 8) {
                        // Add data button spanning width of 2 tiles
                        Button(action: {
                            showAddDataSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
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
                        
                        // Match the spacing of the tiles above (2 empty tile spaces)
                        Spacer()
                            .frame(maxWidth: .infinity)
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                }
            )
        }
        else {
            return AnyView(
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(entries.reversed()) { entry in
                        Text("Results today")
                            .font(AppStyle.Font.analyticsExerciseData)
                            .foregroundColor(AppStyle.Color.white)
                            .padding(.horizontal, AppStyle.Padding.horizontal)
                        entryView(entry)
                    }
                }
                    .padding(.vertical, 10)
                    .padding(.top, 5)
                    .background(AppStyle.Color.backgroundColor)
            )
        }
    }
    
    private func entryView(_ entry: AnalyticsEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(Array(entry.setProgress.enumerated()), id: \.offset) { index, progress in
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
        HStack {
            Text("Set")
                .font(.system(size: 24))
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(progress.weight == floor(progress.weight) ? "\(Int(progress.weight))" : String(progress.weight).replacingOccurrences(of: ".", with: ","))
                .font(.system(size: 30))
                .foregroundColor(AppStyle.Color.greenGlow)
            
            Text("kg")
                .font(AppStyle.Font.analyticsExerciseData)
                .font(.system(size: 35))
                .foregroundColor(AppStyle.Color.green)
            
            Text("\(progress.currentReps) / \(initialReps)")
                .font(.system(size: 24))
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
        .onTapGesture {
            editingEntry = entry
            showAddDataSheet = true
        }
    }
    

    

    
    private var addDataOverlay: some View {
        Group {
            if showAddDataSheet {
                ZStack {
                    // Tappable background area
                    Color.black.opacity(0.5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showAddDataSheet = false
                        }
                    
                    // Overlay content
                    VStack {
                        Spacer()
                        
                        AddAnalyticsEntryView(
                            date: selectedDate,
                            exercise: exercise,
                            existingEntry: editingEntry,
                            onSave: { newEntry in
                                viewModel.saveOrReplaceAnalyticsEntry(
                                    exerciseId: exercise.id,
                                    setProgress: newEntry.setProgress,
                                    date: selectedDate
                                )
                                showAddDataSheet = false
                                editingEntry = nil
                                datesWithData = viewModel.allDatesWithData(for: exercise.id)
                            },
                            onCancel: {
                                showAddDataSheet = false
                                editingEntry = nil
                            }
                        )
                        
                        Spacer()
                    }
                }
                .transition(.opacity)
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
        Text("Set Weight Goal")
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
            TextField("", text: $tempGoal)
                .keyboardType(.decimalPad)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppStyle.Color.white)
                .padding()
                .padding(.trailing, exercise.goal != nil ? 40 : 0)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            goalPlaceholder
        }
    }
    
    private var goalPlaceholder: some View {
        Group {
            if tempGoal.isEmpty {
                Text("Enter goal weight")
                    .font(.system(size: 18, weight: .medium))
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
                        .font(.system(size: 20))
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
        // Update the goal value
        if tempGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            exercise.goal = nil
        } else if let goalValue = Double(tempGoal.replacingOccurrences(of: ",", with: ".")) {
            exercise.goal = goalValue
        }
        
        // Save the exercise with updated goal to storage
        let storageService = ExerciseStorageService()
        let category = exercise.category
        let workoutId = WorkoutStorageService.shared.currentWorkout?.id ?? UUID()
        var exercises = storageService.loadForWorkout(workoutId: workoutId, category: category)
        
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            storageService.saveForWorkout(exercises, workoutId: workoutId, category: category)
        }
        
        showGoalSheet = false
    }
    

    

    

    
    private func formatGoalForInput(_ goal: Double) -> String {
        return WeightFormatter.formatGoalForInput(goal)
    }
    
    private var goalTileNumber: String {
        if let goal = exercise.goal {
            return goal == floor(goal) ? "\(Int(goal))" : String(goal).replacingOccurrences(of: ".", with: ",")
        }
        return "–"
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
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenGlow)

                        Text("Goal kg")
                            .font(.system(size: 10, weight: .medium))
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
                    number: "\(viewModel.totalWeightIncreases(for: exercise.id))",
                    label: "Weight increase",
                    icon: nil,
                    iconColor: .clear
                )

                AnalyticsTileNumberView(
                    number: "\(viewModel.trainingDaysInCurrentMonth(for: exercise.id))",
                    label: "Training \(viewModel.currentMonthName())",
                    icon: nil,
                    iconColor: .clear
                )

                AnalyticsTileNumberView(
                    number: "\(viewModel.trainingSessionsUntilWeightIncrease(for: exercise.id))",
                    label: "Training to increase kg",
                    icon: nil,
                    iconColor: .clear
                )

                AnalyticsTileNumberView(
                    number: "\(viewModel.loadAnalytics(for: exercise.id).count)",
                    label: "Total training",
                    icon: nil,
                    iconColor: .clear
                )
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 8)
    }
    

    

}





struct AnalyticsTileNumberView: View {
    let number: String
    let label: String
    let icon: String?
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AppStyle.Color.greenGlow)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
}

struct AnalyticsTileTextView: View {
    let text: String
    let label: String
    let icon: String?
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(text)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppStyle.Color.greenGlow)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
}


struct AddAnalyticsEntryView: View {
    let date: Date
    let exercise: Exercise
    let existingEntry: AnalyticsEntry?
    var onSave: (AnalyticsEntry) -> Void
    var onCancel: () -> Void
    
    @State private var sets: [SetProgressInput] = []
    
    struct SetProgressInput: Identifiable {
        let id = UUID()
        var weight: Double
        var reps: Int
    }
    
    init(date: Date, exercise: Exercise, existingEntry: AnalyticsEntry? = nil, onSave: @escaping (AnalyticsEntry) -> Void, onCancel: @escaping () -> Void) {
        self.date = date
        self.exercise = exercise
        self.existingEntry = existingEntry
        self.onSave = onSave
        self.onCancel = onCancel
        
        if let existingEntry = existingEntry {
            _sets = State(initialValue: existingEntry.setProgress.map { setProgress in
                SetProgressInput(weight: setProgress.weight, reps: setProgress.currentReps)
            })
        } else {
            _sets = State(initialValue: [
                SetProgressInput(weight: exercise.weight, reps: exercise.reps)
            ])
        }
    }
    
    @State private var showNumberPad = false
    @State private var editingField: EditingField?
    @State private var editingSetIndex: Int?
    
    enum EditingField {
        case weight, reps
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text(existingEntry != nil ? "Edit your data for \(DateFormatter.germanMedium.string(from: date))" : "Add your data for \(DateFormatter.germanMedium.string(from: date))")
                    .font(.headline)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 14)
                
                HStack(spacing: 12) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(width: 60, alignment: .leading)
                    
                    Text("Reps.")
                        .font(.caption)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(width: 60, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 0)
                .padding(.bottom, 4)
                
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    HStack(spacing: 12) {
                        Button(action: {
                            editingSetIndex = index
                            editingField = .weight
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNumberPad = true
                            }
                        }) {
                            let weightValue = index < sets.count ? sets[index].weight : 0.0
                            Text(weightValue == floor(weightValue) ? "\(Int(weightValue))" : String(weightValue).replacingOccurrences(of: ".", with: ","))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppStyle.Color.white)
                                .frame(width: 60, height: 38)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            editingSetIndex = index
                            editingField = .reps
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNumberPad = true
                            }
                        }) {
                            Text("\(index < sets.count ? sets[index].reps : 0)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppStyle.Color.white)
                                .frame(width: 60, height: 38)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                        
                        if sets.count > 1 {
                            Button(action: {
                                if index < sets.count {
                                    withAnimation {
                                        sets.remove(at: index)
                                    }
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(Color(AppStyle.Color.greenGlow))
                                    .font(.system(size: 24))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Button(action: {
                        withAnimation {
                            sets.append(SetProgressInput(weight: exercise.weight, reps: exercise.reps))
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("add more sets")
                        }
                        .foregroundColor(AppStyle.Color.greenGlow)
                        .padding(.vertical, 6)
                    }
                    Spacer()
                }
                
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    Button("Save") {
                        let entry = AnalyticsEntry(
                            exerciseId: exercise.id,
                            date: date,
                            setProgress: sets.map { input in
                                SetProgress(
                                    status: .completedDone,
                                    currentReps: input.reps,
                                    weight: input.weight
                                )
                            }
                        )
                        onSave(entry)
                    }
                    .disabled(sets.contains(where: { $0.weight == 0 || $0.reps == 0 }))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 22)
                    .background(
                        sets.allSatisfy { $0.weight > 0 && $0.reps > 0 }
                        ? AppStyle.Color.green
                        : AppStyle.Color.green.opacity(0.15)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 22)
            .background(AppStyle.Color.exerciseCardBackground)
            .cornerRadius(18)
            .frame(maxWidth: 370)
            
            if showNumberPad {
                GeometryReader { geometry in
                    VStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNumberPad = false
                                }
                                editingField = nil
                                editingSetIndex = nil
                            }
                        
                        CustomNumberPadView(
                            currentValue: getCurrentValue(),
                            isWeight: editingField == .weight,
                            valueType: editingField == .weight ? .decimal : .integer,
                            onValueChange: { newValue in
                                updateCurrentValue(newValue)
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNumberPad = false
                                }
                                editingField = nil
                                editingSetIndex = nil
                            }
                        )
                        .frame(maxHeight: geometry.size.height * 0.5)
                    }
                    .background(Color.black.opacity(0.5))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private func getCurrentValue() -> Double {
        guard let setIndex = editingSetIndex, setIndex < sets.count else { return 0.0 }
        switch editingField {
        case .weight:
            return sets[setIndex].weight
        case .reps:
            return Double(sets[setIndex].reps)
        case .none:
            return 0.0
        }
    }
    
    private func updateCurrentValue(_ newValue: Double) {
        guard let setIndex = editingSetIndex, setIndex < sets.count else { return }
        switch editingField {
        case .weight:
            sets[setIndex].weight = newValue
        case .reps:
            sets[setIndex].reps = Int(newValue)
        case .none:
            break
        }
    }
}



