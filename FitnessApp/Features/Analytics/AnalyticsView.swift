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
        self._exercise = State(initialValue: exercise)
        self.viewModel = viewModel
        self.initialReps = exercise.reps
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry: geometry)
                calendarDialog
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
        .background(Color(hex: "#0A090E"))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Analytics")
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
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
                .fill(AppStyle.Color.greenBlack.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
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
        .frame(height: 80)
    }
    
    private func hillShapeView(geometry: GeometryProxy) -> some View {
        let milestones = viewModel.getWeightProgressionMilestones(for: exercise.id)
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
        let milestones = viewModel.getWeightProgressionMilestones(for: exercise.id)
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
        let milestones = viewModel.getWeightProgressionMilestones(for: exercise.id)
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
    
    private func dynamicMilestonePointView(point: ProgressChartCalculator.ChartPoint, geometry: GeometryProxy) -> some View {
        ZStack {
            // Dotted line from point down to bottom
            Path { path in
                path.move(to: CGPoint(x: point.xPosition, y: point.yPosition + 8))
                path.addLine(to: CGPoint(x: point.xPosition, y: geometry.size.height))
            }
            .stroke(AppStyle.Color.greenGlow.opacity(point.isCurrentWeight ? 0.8 : 0.4), 
                   style: StrokeStyle(lineWidth: point.isCurrentWeight ? 2 : 1, dash: [4, 4]))
            
            // Milestone point
            Circle()
                .fill(AppStyle.Color.greenGlow)
                .frame(width: point.isCurrentWeight ? 10 : 6, height: point.isCurrentWeight ? 10 : 6)
                .position(x: point.xPosition, y: point.yPosition)
                .shadow(color: AppStyle.Color.greenGlow.opacity(0.7), radius: point.isCurrentWeight ? 6 : 3, x: 0, y: 0)
            
            // Weight label
            Text(point.weight == floor(point.weight) ? "\(Int(point.weight))" : String(point.weight).replacingOccurrences(of: ".", with: ","))
                .font(.system(size: point.isCurrentWeight ? 20 : 14, weight: .bold))
                .foregroundColor(AppStyle.Color.greenGlow)
                .position(x: point.xPosition, y: point.yPosition - (point.isCurrentWeight ? 15 : 12))
                .shadow(color: AppStyle.Color.greenGlow.opacity(0.3), radius: point.isCurrentWeight ? 8 : 4, x: 0, y: 0)
        }
    }
    
    private var chartLabelsView: some View {
        // Labels row - below the chart
        HStack {
            // Left: 0 kg (single line)
            Text("0 kg")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppStyle.Color.greenGlow)
            
            Spacer()
            
            // Center: Calendar Entry Point
            Button(action: {
                showCalendarDialog = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                    Text(formattedDateShort(selectedDate))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppStyle.Color.greenGlow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppStyle.Color.greenBlack.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Right: Goal (single line)
            Button(action: {
                tempGoal = exercise.goal != nil ? formatGoalForInput(exercise.goal!) : ""
                showGoalSheet = true
            }) {
                if let goal = exercise.goal {
                    Text("Goal: \(goal == floor(goal) ? "\(Int(goal))" : String(goal).replacingOccurrences(of: ".", with: ",")) kg")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppStyle.Color.greenGlow)
                } else {
                    Text("Set Goal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppStyle.Color.greenGlow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppStyle.Color.greenGlow.opacity(0.5), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(exercise.name)
                .font(AppStyle.Font.analyticsExerciseTitle)
                .foregroundColor(AppStyle.Color.white)
                .fixedSize()
            
            Spacer()
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
                        .foregroundColor(AppStyle.Color.gray)
                        .padding(.horizontal, AppStyle.Padding.horizontal)
                    
                    HStack(alignment: .top, spacing: 12) {
                        Button(action: {
                            showAddDataSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                                Text("Add data")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(AppStyle.Color.greenGlow)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .frame(width: 120, height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppStyle.Color.greenBlack)
                            )
                        }
                        
                        Spacer()
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                viewModel.deleteSetFromEntry(
                                    exerciseId: exercise.id,
                                    entryId: entry.id,
                                    setIndex: index
                                )
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
            .listStyle(PlainListStyle())
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
                .fill(AppStyle.Color.greenBlack.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.top, 9)
        .onTapGesture {
            editingEntry = entry
            showAddDataSheet = true
        }
    }
    
    private var calendarDialog: some View {
        Group {
            if showCalendarDialog {
                ZStack {
                    // Tappable background area
                    Color.black.opacity(0.5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showCalendarDialog = false
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            VStack {
                                Text("Monthly training")
                                    .font(.headline)
                                    .foregroundColor(AppStyle.Color.white)
                                    .padding(.top, 12)
                                    .padding(.horizontal, 16)
                                
                                Spacer().frame(height: 20)
                                
                                CalendarGridView(
                                    selectedDate: $tempDate,
                                    highlightedDates: viewModel.loadAnalyticsDates(for: exercise.id)
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal)
                                
                                actionButtons
                            }
                            .background(AppStyle.Color.greenBlack)
                            .cornerRadius(AppStyle.CornerRadius.defaultButton)
                            .padding(16)
                        }
                        .frame(maxWidth: 400, maxHeight: 250)
                        
                        Spacer()
                    }
                }
                .transition(.opacity)
            }
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
                    // Tappable background area
                    Color.black.opacity(0.5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showGoalSheet = false
                        }
                    
                    // Overlay content
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Text("Set Weight Goal")
                                .font(.headline)
                                .foregroundColor(AppStyle.Color.white)
                                .padding(.top, 16)
                            
                            ZStack(alignment: .trailing) {
                                ZStack(alignment: .leading) {
                                    TextField("", text: $tempGoal)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(AppStyle.Color.white)
                                        .padding()
                                        .padding(.trailing, exercise.goal != nil ? 40 : 0) // Make space for X button
                                        .background(AppStyle.Color.greenBlack)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppStyle.Color.greenGlow.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    // Custom placeholder text in greenGlow
                                    if tempGoal.isEmpty {
                                        Text("Enter goal weight")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
                                            .padding(.leading, 16)
                                            .allowsHitTesting(false)
                                    }
                                }
                                
                                // X button to clear goal - only show when editing existing goal
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
                            
                            HStack(spacing: 16) {
                                Button("Abbrechen") {
                                    showGoalSheet = false
                                }
                                .font(.body)
                                .foregroundColor(AppStyle.Color.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(AppStyle.Color.greenBlack)
                                .cornerRadius(12)
                                
                                Button("Speichern") {
                                    if tempGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        exercise.goal = nil
                                    } else if let goalValue = Double(tempGoal.replacingOccurrences(of: ",", with: ".")) {
                                        exercise.goal = goalValue
                                    }
                                    showGoalSheet = false
                                }
                                .font(.body)
                                .foregroundColor(AppStyle.Color.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(AppStyle.Color.green)
                                .cornerRadius(12)
                            }
                            .padding(.bottom, 16)
                        }
                        .padding(.horizontal, 24)
                        .background(AppStyle.Color.greenBlack)
                        .cornerRadius(16)
                        .padding(.horizontal, 32)
                        
                        Spacer()
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                showCalendarDialog = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
            
            Button("Select") {
                selectedDate = tempDate
                showCalendarDialog = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(AppStyle.Color.green)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    private func formattedDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    private func formatGoalForInput(_ goal: Double) -> String {
        if goal == floor(goal) {
            // Ganze Zahl - keine Dezimalstellen
            return "\(Int(goal))"
        } else {
            // Dezimalzahl - mit deutschem Komma
            return String(goal).replacingOccurrences(of: ".", with: ",")
        }
    }
    
    private var weightMilestoneView: some View {
        HStack(alignment: .top, spacing: 0) {
            AnalyticsTileView(
                number: "\(viewModel.weightIncreasesInCurrentMonth(for: exercise.id))",
                label: "Increase by weight",
                icon: "arrow.up.right",
                iconColor: .yellow
            )
            
            Spacer()
            
            AnalyticsTileView(
                number: "\(viewModel.trainingDaysInCurrentMonth(for: exercise.id))",
                label: "Training \(viewModel.currentMonthName())",
                icon: "arrow.up.right",
                iconColor: .clear
            )
            
            Spacer()
            
            AnalyticsTileView(
                number: "\(viewModel.trainingSessionsUntilWeightIncrease(for: exercise.id))",
                label: "trainings to increase weight",
                icon: "arrow.up.circle",
                iconColor: AppStyle.Color.greenGlow
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    

    

}





struct AnalyticsTileView: View {
    let number: String
    let label: String
    let icon: String?
    let iconColor: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppStyle.Color.greenBlack.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                )
            
            VStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                Text(number)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 96)
            }
            .padding(12)
        }
        .frame(width: 120, height: 120, alignment: .center)
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
                Text(existingEntry != nil ? "Edit your data for \(formattedDate(date))" : "Add your data for \(formattedDate(date))")
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
                                .background(AppStyle.Color.greenBlack)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppStyle.Color.greenGlow, lineWidth: 1)
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
                                .background(AppStyle.Color.greenBlack)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppStyle.Color.greenGlow, lineWidth: 1)
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
                    Button("Abbrechen") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(AppStyle.Color.greenBlack)
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    Button("Speichern") {
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
            .background(AppStyle.Color.greenBlack)
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

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.locale = Locale(identifier: "de_DE")
    return formatter.string(from: date)
}

