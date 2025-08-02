import SwiftUI

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AnalyticsView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    private let initialReps: Int
    @State private var selectedDate: Date = Date()
    @State private var originalDate: Date = Date()
    @State private var tempDate: Date = Date()
    @State private var showCalendarDialog: Bool = false
    @State private var showGoalWeightDialog = false
    @State private var goalWeight: Int = 0
    @State private var milestoneHeight: CGFloat = 0
    @State private var datesWithData: Set<Date> = []
    @State private var showAddDataSheet: Bool = false
    @State private var showEditSetSheet: Bool = false
    @State private var editingEntry: AnalyticsEntry?
    @State private var editingSetIndex: Int?
    
    private let paddingAmount: CGFloat = 16
    
    init(exercise: Exercise, viewModel: AnalyticsViewModel) {
        self.exercise = exercise
        self.viewModel = viewModel
        self.initialReps = exercise.reps
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry: geometry)
                calendarDialog
                editSetOverlay
                addDataOverlay
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
            VStack(alignment: .leading, spacing: 16) {
                headerView
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
        .background(AppStyle.Color.black)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Analytics")
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
        .onAppear {
            originalDate = selectedDate
            datesWithData = viewModel.allDatesWithData(for: exercise.id)
            
            if let savedGoal = UserDefaults.standard.value(forKey: "goalWeight_\(exercise.id)") as? Int {
                goalWeight = savedGoal
            }
        }
        .overlay(goalWeightDialog)
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.name)
                .font(AppStyle.Font.analyticsExerciseTitle)
                .foregroundColor(AppStyle.Color.white)
                .fixedSize()
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .imageScale(.medium)
                    .onTapGesture {
                        showCalendarDialog = true
                    }
                
                Text(formattedDate(selectedDate))
                    .font(.body)
                    .foregroundColor(AppStyle.Color.white)
                    .onTapGesture {
                        showCalendarDialog = true
                    }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(AppStyle.Color.greenDark)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, 32)
    }
    
    private var resultsView: some View {
        let entries = viewModel.loadAnalytics(for: exercise.id, on: selectedDate)
        
        if entries.isEmpty {
            return AnyView(
                VStack(spacing: 12) {
                    Text("Keine Daten für das ausgewählte Datum verfügbar")
                        .font(AppStyle.Font.defaultFont)
                        .foregroundColor(AppStyle.Color.gray)
                        .padding(.horizontal, AppStyle.Padding.horizontal)
                    
                    Button(action: {
                        showAddDataSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                            Text("Daten hinzufügen")
                                .font(.body)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(AppStyle.Color.green)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .fill(AppStyle.Color.greenBlack)
                        )
                    }
                }
            )
        }
        else {
            return AnyView(
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(entries.reversed()) { entry in
                        Text("Results today")
                            .font(AppStyle.Font.analyticsExerciseData)
                            .foregroundColor(AppStyle.Color.gray)
                            .padding(.horizontal, AppStyle.Padding.horizontal)
                        entryView(entry)
                    }
                }
                    .padding(.vertical, 10)
                    .padding(.top, 10)
                    .background(AppStyle.Color.black)
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
        .background(AppStyle.Color.greenDark)
        .cornerRadius(AppStyle.CornerRadius.defaultButton)
        .padding(.top, 4)
        .onTapGesture {
            editingEntry = entry
            editingSetIndex = index
            showEditSetSheet = true
        }
    }
    
    private var calendarDialog: some View {
        Group {
            if showCalendarDialog {
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
                .background(Color.black.opacity(0.5))
                .transition(.opacity)
            }
        }
    }
    
    private var editSetOverlay: some View {
        Group {
            if showEditSetSheet, let entry = editingEntry, let setIndex = editingSetIndex {
                VStack {
                    Spacer()
                    
                    EditSetView(
                        entry: entry,
                        setIndex: setIndex,
                        exercise: exercise,
                        onSave: { updatedSetProgress in
                            viewModel.updateSetInEntry(
                                exerciseId: exercise.id,
                                entryId: entry.id,
                                setIndex: setIndex,
                                newSetProgress: updatedSetProgress
                            )
                            showEditSetSheet = false
                            datesWithData = viewModel.allDatesWithData(for: exercise.id)
                        },
                        onCancel: {
                            showEditSetSheet = false
                        }
                    )
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.5))
                .transition(.opacity)
            }
        }
    }
    
    private var addDataOverlay: some View {
        Group {
            if showAddDataSheet {
                VStack {
                    Spacer()
                    
                    AddAnalyticsEntryView(
                        date: selectedDate,
                        exercise: exercise,
                        onSave: { newEntry in
                            viewModel.saveOrReplaceAnalyticsEntry(
                                exerciseId: exercise.id,
                                setProgress: newEntry.setProgress,
                                date: selectedDate
                            )
                            showAddDataSheet = false
                            datesWithData = viewModel.allDatesWithData(for: exercise.id)
                        },
                        onCancel: {
                            showAddDataSheet = false
                        }
                    )
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.5))
                .transition(.opacity)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Abbrechen") {
                showCalendarDialog = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
            
            Button("Auswählen") {
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
    
    private func saveGoalWeight() {
        UserDefaults.standard.set(goalWeight, forKey: "goalWeight_\(exercise.id)")
    }
    
    private var weightMilestoneView: some View {
        HStack(alignment: .top, spacing: 12) {
            AnalyticsTileView(
                number: "\(viewModel.weightIncreasesInCurrentMonth(for: exercise.id))",
                label: "Steigerungen KG",
                icon: "arrow.up.right",
                iconColor: .yellow
            )
            
            AnalyticsTileView(
                number: "\(viewModel.trainingDaysInCurrentMonth(for: exercise.id))",
                label: "Training \(viewModel.currentMonthName())",
                icon: "arrow.up.right",
                iconColor: .clear
            )
            
            goalWeightArea()
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 8)
    }
    
    private func goalWeightArea() -> some View {
        VStack(spacing: 3) {
            Group {
                if goalWeight == 0 {
                    ZStack {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .foregroundColor(AppStyle.Color.greenGlow)
                        
                        VStack(spacing: 2) {
                            Text("ZIEL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppStyle.Color.greenGlow)
                            Text("HINZUFÜGEN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppStyle.Color.greenGlow)
                        }
                    }
                    .frame(width: 77, height: 77)
                    .onTapGesture {
                        showGoalWeightDialog = true
                    }
                } else {
                    VStack(spacing: -2) {
                        Spacer(minLength: 16)
                        Text("\(goalWeight)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenDark)
                        
                        Text("kg")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenDark)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 49, height: 49)
                    .background(AppStyle.Color.greenGlow)
                    .clipShape(Circle())
                    .onTapGesture {
                        showGoalWeightDialog = true
                    }
                }
            }
            
            let current = viewModel.loadAnalytics(for: exercise.id, on: selectedDate).first?.setProgress.first?.weight ?? exercise.weight
            let currentInt = Int(current)
            
            if goalWeight > currentInt {
                let isMultipleOfTen = currentInt % 10 == 0
                let firstMilestone = isMultipleOfTen ? currentInt + 5 : Int(ceil(Double(currentInt) / 10.0)) * 10
                let secondMilestone = firstMilestone + 5
                
                let filteredMilestones = [secondMilestone, firstMilestone]
                    .filter { $0 < goalWeight }
                    .sorted(by: >)
                
                VStack(spacing: 22) {
                    ForEach(filteredMilestones, id: \.self) { milestone in
                        ZStack {
                            Circle()
                                .fill(AppStyle.Color.greenGlow)
                                .frame(width: 8, height: 8)
                            
                            Text("\(milestone)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppStyle.Color.greenGlow)
                                .offset(x: 20)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Circle()
                        .fill(AppStyle.Color.greenGlow.opacity(0.2))
                        .frame(width: 4, height: 4)
                }
                .overlay(
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [AppStyle.Color.greenGlow.opacity(0.4), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 3),
                    alignment: .center
                )
            } else if goalWeight == 0 {
                VStack {}
                    .frame(height: 40)
                    .overlay(
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [AppStyle.Color.greenGlow.opacity(0.4), .clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: 3),
                        alignment: .center
                    )
            }
            
            VStack(spacing: -2) {
                Text(exercise.weight == floor(exercise.weight) ? "\(Int(exercise.weight))" : String(exercise.weight).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)
                Text("kg")
                    .font(.system(size: 9))
                    .foregroundColor(AppStyle.Color.greenGlow)
            }
            .frame(width: 32, height: 32)
            .background(AppStyle.Color.black)
            .overlay(
                Circle()
                    .stroke(AppStyle.Color.greenGlow, lineWidth: 1.5)
            )
            .clipShape(Circle())
            .padding(.top, -20)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private var goalWeightDialog: some View {
        Group {
            if showGoalWeightDialog {
                VStack(spacing: 16) {
                    Text("Set Goal Weight")
                        .font(.headline)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                    
                    Text("Minimum weight: \(Int(exercise.weight) + 15) kg")
                        .font(.subheadline)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.horizontal, 16)
                    
                    TextField("Enter goal weight (kg)", text: Binding(
                        get: { String(goalWeight) },
                        set: { if let value = NumberFormatter().number(from: $0) {
                            goalWeight = value.intValue
                        }}
                    ))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(width: 220, height: 60)
                    .background(
                        AppStyle.Color.greenBlack
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppStyle.Color.white, lineWidth: 1)
                    )
                    .keyboardType(.numberPad)
                    
                    Text("Current: \(exercise.weight == floor(exercise.weight) ? "\(Int(exercise.weight))" : String(exercise.weight).replacingOccurrences(of: ".", with: ",")) kg")
                        .font(.subheadline)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            showGoalWeightDialog = false
                        }
                        .font(.body)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(AppStyle.Color.greenBlack)
                        .cornerRadius(AppStyle.CornerRadius.defaultButton)
                        
                        Button("Save") {
                            saveGoalWeight()
                            showGoalWeightDialog = false
                        }
                        .font(.body)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(goalWeight >= Int(exercise.weight) + 15
                                    ? AppStyle.Color.green
                                    : AppStyle.Color.green.opacity(0.15))
                        .cornerRadius(AppStyle.CornerRadius.defaultButton)
                        .disabled(goalWeight < Int(exercise.weight) + 15)
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: 280, height: 250)
                .background(AppStyle.Color.greenBlack)
                .cornerRadius(AppStyle.CornerRadius.defaultButton)
                .padding(16)
            }
        }
    }
}


struct EditSetView: View {
    let entry: AnalyticsEntry
    let setIndex: Int
    let exercise: Exercise
    var onSave: (SetProgress) -> Void
    var onCancel: () -> Void
    
    @State private var weight: Double
    @State private var reps: Int
    @State private var showNumberPad = false
    @State private var editingField: EditingField?
    
    enum EditingField {
        case weight, reps
    }
    
    init(entry: AnalyticsEntry, setIndex: Int, exercise: Exercise, onSave: @escaping (SetProgress) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.setIndex = setIndex
        self.exercise = exercise
        self.onSave = onSave
        self.onCancel = onCancel
        
        let currentSet = entry.setProgress[setIndex]
        _weight = State(initialValue: currentSet.weight)
        _reps = State(initialValue: currentSet.currentReps)
    }
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                VStack(spacing: 24) {
                Text("Set bearbeiten")
                    .font(.headline)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 14)
                
                Text("Datum: \(formattedDate(entry.date))")
                    .font(.subheadline)
                    .foregroundColor(AppStyle.Color.gray)
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gewicht")
                            .font(.caption)
                            .foregroundColor(AppStyle.Color.white)
                        Button(action: {
                            editingField = .weight
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNumberPad = true
                            }
                        }) {
                            Text(weight == floor(weight) ? "\(Int(weight))" : String(weight).replacingOccurrences(of: ".", with: ","))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppStyle.Color.white)
                                .frame(width: 80, height: 48)
                                .background(AppStyle.Color.greenBlack)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppStyle.Color.greenGlow, lineWidth: 1)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wiederholungen")
                            .font(.caption)
                            .foregroundColor(AppStyle.Color.white)
                        Button(action: {
                            editingField = .reps
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showNumberPad = true
                            }
                        }) {
                            Text("\(reps)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppStyle.Color.white)
                                .frame(width: 80, height: 48)
                                .background(AppStyle.Color.greenBlack)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppStyle.Color.greenGlow, lineWidth: 1)
                                )
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    Button("Abbrechen") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(AppStyle.Color.greenBlack)
                    .cornerRadius(12)
                    
                    Button("Speichern") {
                        let updatedSet = SetProgress(
                            status: .completedDone,
                            currentReps: reps,
                            weight: weight
                        )
                        onSave(updatedSet)
                    }
                    .disabled(weight <= 0 || reps <= 0)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        weight > 0 && reps > 0
                        ? AppStyle.Color.green
                        : AppStyle.Color.green.opacity(0.15)
                    )
                    .cornerRadius(12)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
                .background(AppStyle.Color.greenBlack)
                .cornerRadius(18)
                .frame(maxWidth: 320, maxHeight: 280)
                
                Spacer()
            }
            
            if showNumberPad {
                GeometryReader { geometry in
                    VStack {
                        // Tappable background area
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNumberPad = false
                                }
                                editingField = nil
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
        switch editingField {
        case .weight:
            return weight
        case .reps:
            return Double(reps)
        case .none:
            return 0.0
        }
    }
    
    private func updateCurrentValue(_ newValue: Double) {
        switch editingField {
        case .weight:
            weight = newValue
        case .reps:
            reps = Int(newValue)
        case .none:
            break
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
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
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        AppStyle.Color.black,
                        AppStyle.Color.greenBlack
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#171F22"), lineWidth: 1.2)
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
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppStyle.Color.greenGlow, lineWidth: 1)
                    )
            }
            .padding(12)
        }
        .frame(width: 120, height: 120, alignment: .center)
    }
}


struct AddAnalyticsEntryView: View {
    let date: Date
    let exercise: Exercise
    var onSave: (AnalyticsEntry) -> Void
    var onCancel: () -> Void
    
    @State private var sets: [SetProgressInput] = []
    
    struct SetProgressInput: Identifiable {
        let id = UUID()
        var weight: Double
        var reps: Int
    }
    
    init(date: Date, exercise: Exercise, onSave: @escaping (AnalyticsEntry) -> Void, onCancel: @escaping () -> Void) {
        self.date = date
        self.exercise = exercise
        self.onSave = onSave
        self.onCancel = onCancel
        _sets = State(initialValue: [
            SetProgressInput(weight: exercise.weight, reps: exercise.reps)
        ])
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
                Text("Daten hinzufügen für \(formattedDate(date))")
                    .font(.headline)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 14)
                
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gewicht")
                            .font(.caption)
                            .foregroundColor(AppStyle.Color.white)
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
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wiederh.")
                            .font(.caption)
                            .foregroundColor(AppStyle.Color.white)
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
                                .foregroundColor(.red)
                                .font(.system(size: 24))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Button(action: {
                withAnimation {
                    sets.append(SetProgressInput(weight: exercise.weight, reps: exercise.reps))
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Set hinzufügen")
                }
                .foregroundColor(AppStyle.Color.green)
                .padding(.vertical, 6)
            }
            
            HStack {
                Button("Abbrechen") {
                    onCancel()
                }
                .foregroundColor(.red)
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
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(AppStyle.Color.greenBlack)
            .cornerRadius(18)
            .frame(maxWidth: 370, maxHeight: 380)
            
            if showNumberPad {
                GeometryReader { geometry in
                    VStack {
                        // Tappable background area
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

