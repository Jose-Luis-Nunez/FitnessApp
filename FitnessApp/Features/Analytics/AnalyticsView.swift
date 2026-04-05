import SwiftUI

struct AnalyticsView: View {
    @State private var exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    private let initialReps: Int
    @State private var selectedDate: Date
    @State private var showCalendarDialog: Bool = false

    @State private var showAddDataSheet: Bool = false
    @State private var editingEntry: AnalyticsEntry?
    @State private var showGoalSheet: Bool = false
    @State private var tempGoal: String = ""
    
    init(exercise: Exercise, viewModel: AnalyticsViewModel, initialDate: Date = Date()) {
        let storageService = ExerciseStorageService()
        let category = exercise.category
        let workoutId = WorkoutStorageService.shared.currentWorkout?.id ?? UUID()
        let exercises = storageService.loadForWorkout(workoutId: workoutId, category: category)
        let latestExercise = exercises.first(where: { $0.id == exercise.id }) ?? exercise
        
        self._exercise = State(initialValue: latestExercise)
        self.viewModel = viewModel
        self.initialReps = latestExercise.reps
        self._selectedDate = State(initialValue: initialDate)
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
                    .font(.system(size: 9, weight: .medium))
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
                    .font(.system(size: 9, weight: .medium))
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
        let weightText = point.weight == floor(point.weight) ? "\(Int(point.weight))" : String(point.weight).replacingOccurrences(of: ".", with: ",")

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
                .font(.system(size: point.isCurrentWeight ? 16 : 11, weight: .bold))
                .foregroundColor(AppStyle.Color.greenGlow)
                .position(x: point.xPosition, y: point.yPosition - (point.isCurrentWeight ? 15 : 12))

            if let date = point.date {
                Text(Self.chartDateFormatter.string(from: date))
                    .font(.system(size: 9, weight: .medium))
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
                        .font(.system(size: 14, weight: .medium))
                    Text(DateFormatter.germanShort.string(from: selectedDate))
                        .font(.system(size: 14, weight: .medium))
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
    
    @ViewBuilder
    private var resultsView: some View {
        let entries = viewModel.loadAnalytics(for: exercise.id, on: selectedDate)
        
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
            
            if exercise.hasWeight {
                Text(progress.weight == floor(progress.weight) ? "\(Int(progress.weight))" : String(progress.weight).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 30))
                    .foregroundColor(AppStyle.Color.greenGlow)
                
                Text("kg")
                    .font(.system(size: 35))
                    .foregroundColor(AppStyle.Color.green)
            }
            
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
                Text(exercise.hasWeight ? "Enter goal weight" : "Enter goal reps")
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
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenGlow)

                        Text(exercise.hasWeight ? "Goal kg" : "Goal Reps")
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

struct AnalyticsTileNumberView: View {
    let number: String
    let label: String
    
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
                    if exercise.hasWeight {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(AppStyle.Color.white)
                            .frame(width: 60, alignment: .leading)
                    }
                    
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
                        if exercise.hasWeight {
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
                    .disabled(exercise.hasWeight
                        ? sets.contains(where: { $0.weight == 0 || $0.reps == 0 })
                        : sets.contains(where: { $0.reps == 0 })
                    )
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 22)
                    .background(
                        (exercise.hasWeight
                            ? sets.allSatisfy { $0.weight > 0 && $0.reps > 0 }
                            : sets.allSatisfy { $0.reps > 0 })
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
