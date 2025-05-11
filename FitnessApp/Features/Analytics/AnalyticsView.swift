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
            }
        }
    }
    
    private func mainContent(geometry: GeometryProxy)->some View {
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
        .background(AppStyle.Color.backgroundColor)
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
                Text("Keine Daten für das ausgewählte Datum verfügbar")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(AppStyle.Color.gray)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
            )
        } else {
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
                    .background(AppStyle.Color.backgroundColor)
            )
        }
    }
    
    private func entryView(_ entry: AnalyticsEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(entry.setProgress, id: \.self) { progress in
                HStack {
                    Text("Set")
                        .font(.system(size: 24))
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(progress.weight)")
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
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
    
    private var calendarDialog: some View {
        Group {
            if showCalendarDialog {
                VStack(spacing: 16) {
                    VStack {
                        Text("Wähle ein Datum")
                            .font(.headline)
                            .foregroundColor(AppStyle.Color.white)
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                        
                        DatePicker(
                            "",
                            selection: $tempDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .accentColor(AppStyle.Color.green)
                        .background(AppStyle.Color.greenBlack)
                        .cornerRadius(12)
                        .padding([.top, .bottom], 2)
                        .padding(.horizontal, 16)
                        
                        actionButtons
                    }
                    .background(AppStyle.Color.greenBlack)
                    .cornerRadius(AppStyle.CornerRadius.defaultButton)
                    .padding(16)
                }
                .frame(maxWidth: 400, maxHeight: 250)
                .transition(.move(edge: .bottom))
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
    
    private var goalWeightDialog: some View {
        Group {
            if showGoalWeightDialog {
                VStack(spacing: 16) {
                    
                    Text("Set Goal Weight")
                        .font(.headline)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                    
                    Text("Minimum weight: \(exercise.weight + 15) kg")
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
                    
                    Text("Current: \(exercise.weight) kg")
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
                        .background(goalWeight >= exercise.weight + 15
                                    ? AppStyle.Color.green
                                    : AppStyle.Color.green.opacity(0.15))
                        .cornerRadius(AppStyle.CornerRadius.defaultButton)
                        .disabled(goalWeight < exercise.weight + 15)
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
    
    private var weightMilestoneView: some View {
        VStack(spacing: 12) {
            
            
            Group {
                if goalWeight == 0 {
                    ZStack {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(AppStyle.Color.greenGlow)
                        
                        VStack(spacing: 4) {
                            Text("ZIEL")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppStyle.Color.greenGlow)
                            Text("HINZUFÜGEN")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppStyle.Color.greenGlow)
                        }
                    }
                    .frame(width: 110, height: 110)
                    .onTapGesture {
                        showGoalWeightDialog = true
                    }
                } else {
                    VStack(spacing: -4) {
                        Spacer(minLength: 22)
                        
                        Text("\(goalWeight)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenDark)
                        Text("kg")
                            .font(.system(size: 14,weight: .bold))
                            .foregroundColor(AppStyle.Color.greenDark)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 70, height: 70)
                    .background(AppStyle.Color.greenGlow)
                    .clipShape(Circle())
                    .onTapGesture {
                        showGoalWeightDialog = true
                    }
                }
            }
            
            if let current = viewModel.loadAnalytics(for: exercise.id, on: selectedDate).first?.setProgress.first?.weight,
               goalWeight > current {
                
                let isMultipleOfTen = current % 10 == 0
                let firstMilestone = isMultipleOfTen ? current + 5 : Int(ceil(Double(current) / 10.0)) * 10
                let secondMilestone = firstMilestone + 5
                
                let filteredMilestones = [secondMilestone, firstMilestone]
                    .filter { $0 < goalWeight }
                    .sorted(by: >)
                
                VStack(spacing: 32) {
                    
                    ForEach(filteredMilestones, id: \.self) { milestone in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppStyle.Color.greenGlow)
                                .frame(width: 12, height: 12)
                            
                            Text("\(milestone) kg")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppStyle.Color.greenGlow)
                                .padding(.leading, 6)
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(x: 26)
                    }
                    Circle()
                        .fill(AppStyle.Color.greenGlow.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
                .overlay(
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [AppStyle.Color.greenGlow.opacity(0.4), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 4),
                    alignment: .center
                )
            } else if goalWeight == 0 {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [AppStyle.Color.greenGlow.opacity(0.4), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: 60)
                
            }
            
            VStack(spacing: -4) {
                Text("\(exercise.weight)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppStyle.Color.white)
                Text("kg")
                    .font(.caption2)
                    .foregroundColor(AppStyle.Color.white)
            }
            .frame(width: 45, height: 45)
            .background(AppStyle.Color.backgroundColor)
            .overlay(
                Circle()
                    .stroke(AppStyle.Color.greenGlow, lineWidth: 2)
            )
            .clipShape(Circle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
