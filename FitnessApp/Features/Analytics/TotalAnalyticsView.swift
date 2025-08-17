import SwiftUI

struct TotalAnalyticsView: View {
    @ObservedObject var viewModel: TotalAnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var showCalendarDialog: Bool = false
    @State private var tempDate: Date = Date()
    @State private var datesWithData: Set<Date> = []
    
    private let paddingAmount: CGFloat = 16
    
    init(viewModel: TotalAnalyticsViewModel = TotalAnalyticsViewModel()) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry: geometry)
                calendarDialog
            }
        }
        .background(Color(hex: "#0A090E"))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Total Analytics")
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
        .onAppear {
            datesWithData = viewModel.allDatesWithData()
        }
    }
    
    private func mainContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                
                // Overall Statistics
                overallStatsView
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.vertical, 12)
                
                // Category Progress Slider
                categoryProgressView
                    .padding(.vertical, 8)
                
                Spacer()
            }
            .frame(minHeight: geometry.size.height)
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gesamtübersicht")
                        .font(AppStyle.Font.analyticsExerciseTitle)
                        .foregroundColor(AppStyle.Color.white)
                        .fixedSize()
                    
                    // Current workout indicator
                    if let currentWorkout = WorkoutStorageService.shared.currentWorkout {
                        Text("Workout: \(currentWorkout.name)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppStyle.Color.greenGlow.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Calendar button
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
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, 15)
        .padding(.bottom, 10)
    }
    
    private var overallStatsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First row - 3 tiles
            HStack(alignment: .top, spacing: 8) {
                AnalyticsTileNumberView(
                    number: "\(viewModel.totalWorkoutDaysInCurrentMonth())",
                    label: "Training \(viewModel.currentMonthName())",
                    icon: nil,
                    iconColor: .clear
                )
                
                AnalyticsTileNumberView(
                    number: "\(viewModel.totalWorkoutDaysInYear())",
                    label: "Training 2025",
                    icon: nil,
                    iconColor: .clear
                )
                
                let mostTrained = viewModel.getMostTrainedCategory()
                AnalyticsTileTextView(
                    text: "\(mostTrained.category.displayName)",
                    label: "Category with most exercise",
                    icon: nil,
                    iconColor: .clear
                )
            }
            
            // Second row - 3 tiles
            HStack(alignment: .top, spacing: 8) {
                let leastTrained = viewModel.getLeastTrainedCategory()
                AnalyticsTileTextView(
                    text: "\(leastTrained.category.displayName)",
                    label: "Category with least exercise",
                    icon: nil,
                    iconColor: .clear
                )
                
                let mostImproved = viewModel.getCategoryWithMostImprovements()
                AnalyticsTileNumberView(
                    number: "\(mostImproved.improvements)",
                    label: "Häufigste Steigerungen: \(mostImproved.category.displayName)",
                    icon: nil,
                    iconColor: .clear
                )
                
                let mostWeightGains = viewModel.getCategoryWithMostWeightGains()
                AnalyticsTileNumberView(
                    number: "\(formatWeight(mostWeightGains.totalGains))kg",
                    label: "Größte Steigerungen: \(mostWeightGains.category.displayName)",
                    icon: nil,
                    iconColor: .clear
                )
            }
        }
    }
    

    
    private var categoryProgressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header without swipe hint
            Text("Categories")
                .font(AppStyle.Font.analyticsExerciseData)
                .foregroundColor(AppStyle.Color.white)
                .padding(.horizontal, AppStyle.Padding.horizontal)
            
            // Horizontal scrollable slider for categories with peek effect
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) { // Small spacing between cards
                        let categoryData = viewModel.getCategoryProgressData()
                        // Card width: 90% of container for 10% peek effect
                        let cardWidth = geometry.size.width * 0.90 - (AppStyle.Padding.horizontal * 2)
                        
                        ForEach(Array(categoryData.enumerated()), id: \.offset) { index, data in
                            categoryCard(data: data)
                                .frame(width: cardWidth) // 90% width for 10% peek effect
                                .frame(height: 300) // Fixed height for all cards
                        }
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled() // Allow peeking of next card
            }
            .frame(height: 320) // Fixed container height
        }
    }
    
    private func categoryCard(data: CategoryProgressData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header - fixed at top
            HStack {
                Text("Category: \(data.category.displayName)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppStyle.Color.white)
                
                Spacer()
                
                Text("\(data.exerciseCount) exercise\(data.exerciseCount == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(AppStyle.Color.greenGlow)
            }
            .frame(height: 30) // Fixed header height
            
            // Exercise content area - scrollable
            if data.exercises.isEmpty {
                VStack {
                    Spacer()
                    Text("No training")
                        .font(.system(size: 14))
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Exercise list - scrollable within fixed card height
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(data.exercises.enumerated()), id: \.offset) { index, exerciseData in
                                exerciseProgressRow(data: exerciseData)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.bottom, 20) // Extra space for fade indicator
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Simple scroll indicator at bottom if there's more content
                    if data.exercises.count > 3 { // Show if more than 3 exercises
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AppStyle.Color.white.opacity(0.5))
                                    .padding(.bottom, 4) // Further down
                                Spacer()
                            }
                        }
                        .allowsHitTesting(false) // Don't intercept scroll gestures
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill provided frame
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppStyle.Color.greenBlack.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func exerciseProgressRow(data: ExerciseProgressData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.exercise.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppStyle.Color.white)
            
            HStack {
                // Initial weight with start date
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start")
                        .font(.system(size: 10))
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    HStack(spacing: 4) {
                        Text("\(formatWeight(data.initialWeight)) kg")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppStyle.Color.white)
                        Text("(\(formatDateShort(data.startDate)))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Current weight
                VStack(alignment: .center, spacing: 2) {
                    Text("Current")
                        .font(.system(size: 10))
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    Text("\(formatWeight(data.currentWeight)) kg")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
                
                Spacer()
                
                // Progress with frequency and percentage
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Progress")
                        .font(.system(size: 10))
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    
                    let difference = data.weightDifference
                    let percentage = data.weightPercentage
                    let frequency = data.improvementFrequency
                    
                    VStack(alignment: .trailing, spacing: 1) {
                        // Weight change with frequency
                        HStack(spacing: 2) {
                            if difference > 0 {
                                Text("+\(formatWeight(difference)) kg")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppStyle.Color.green)
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(AppStyle.Color.green.opacity(0.7))
                            } else if difference < 0 {
                                Text("\(formatWeight(difference)) kg")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.red.opacity(0.7))
                            } else {
                                Text("0 kg")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppStyle.Color.white.opacity(0.6))
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(AppStyle.Color.white.opacity(0.4))
                            }
                        }
                        
                        // Percentage
                        if percentage != 0 {
                            Text(percentage > 0 ? "+\(Int(percentage))%" : "\(Int(percentage))%")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(percentage > 0 ? AppStyle.Color.green.opacity(0.8) : .red.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
                                Text("Training Calendar")
                                    .font(.headline)
                                    .foregroundColor(AppStyle.Color.white)
                                    .padding(.top, 12)
                                    .padding(.horizontal, 16)
                                
                                Spacer().frame(height: 20)
                                
                                CalendarGridView(
                                    selectedDate: $tempDate,
                                    highlightedDates: Array(datesWithData)
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
    
    // MARK: - Helper Functions
    
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
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

    
    private func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
            if days <= 7 {
                return "\(days) day\(days == 1 ? "" : "s") ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yy"
                return formatter.string(from: date)
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        } else {
            return String(weight).replacingOccurrences(of: ".", with: ",")
        }
    }
    
    private func getCategoryDisplayName(_ category: MuscleCategoryGroup) -> String {
        switch category {
        case .arms:
            return "Arme"
        case .abs:
            return "Bauch"
        case .back:
            return "Rücken"
        case .legs:
            return "Beine"
        case .chest:
            return "Brust"
        }
    }
}
