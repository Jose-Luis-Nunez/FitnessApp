import SwiftUI

// MARK: - Analytics Tile Data Model

struct AnalyticsTileData: Identifiable {
    let id = UUID()
    let type: TileType
    let value: String
    let label: String
    let icon: String?
    let iconColor: Color
    
    enum TileType {
        case number
        case text
    }
}



struct TotalAnalyticsView: View {
    @ObservedObject var viewModel: TotalAnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var showCalendarDialog: Bool = false
    @State private var showWorkoutDetail: Bool = false
    @State private var showRhythmDetail: Bool = false

    @State private var datesWithData: Set<Date> = []
    
    private let paddingAmount: CGFloat = 16
    
    init(viewModel: TotalAnalyticsViewModel = TotalAnalyticsViewModel()) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry: geometry)
                CalendarDialogView(
                    isPresented: $showCalendarDialog,
                    selectedDate: $selectedDate,
                    highlightedDates: Array(datesWithData),
                    title: "Training Calendar"
                )
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .standardToolbar(title: "Total Analytics")
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
        .onTapGesture {
            // Close detail views if shown and tap is outside
            if showWorkoutDetail {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWorkoutDetail = false
                }
            } else if showRhythmDetail {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRhythmDetail = false
                }
            }
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
                        Text(DateFormatter.germanShort.string(from: selectedDate))
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
    
    private var analyticsTiles: [AnalyticsTileData] {
        let mostTrained = viewModel.getMostTrainedCategory()
        let leastTrained = viewModel.getLeastTrainedCategory()
        let mostImproved = viewModel.getCategoryWithMostImprovements()
        let completionRate = viewModel.getLastTrainingDayCompletionRate()
        
        return [
            AnalyticsTileData(
                type: .number,
                value: "\(viewModel.totalWorkoutDaysInCurrentMonth())",
                label: "Training \(viewModel.currentMonthName())",
                icon: nil,
                iconColor: .clear
            ),
            AnalyticsTileData(
                type: .number,
                value: "\(viewModel.totalWorkoutDaysInYear())",
                label: "Training 2025",
                icon: nil,
                iconColor: .clear
            ),
            AnalyticsTileData(
                type: .number,
                value: "\(completionRate.percentage)%",
                label: "Last Workout Completion",
                icon: nil,
                iconColor: .clear
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(viewModel.getTrainingRhythm())",
                label: "Training Rhythm",
                icon: nil,
                iconColor: .clear
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(mostTrained.category.displayName)",
                label: "Category with most exercise",
                icon: nil,
                iconColor: .clear
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(leastTrained.category.displayName)",
                label: "Category with least exercise",
                icon: nil,
                iconColor: .clear
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(mostImproved.category.displayName)",
                label: "Category with most Improvements",
                icon: nil,
                iconColor: .clear
            )
        ]
    }
    
    @ViewBuilder
    private var overallStatsView: some View {
        if showWorkoutDetail {
            workoutDetailView
        } else if showRhythmDetail {
            rhythmDetailView
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(analyticsTiles) { tile in
                    analyticsTileView(for: tile)
                }
            }
        }
    }
    
    @ViewBuilder
    private func analyticsTileView(for tile: AnalyticsTileData) -> some View {
        let tileView = Group {
            switch tile.type {
            case .number:
                AnalyticsTileNumberView(
                    number: tile.value,
                    label: tile.label,
                    icon: tile.icon,
                    iconColor: tile.iconColor
                )
            case .text:
                AnalyticsTileTextView(
                    text: tile.value,
                    label: tile.label,
                    icon: tile.icon,
                    iconColor: tile.iconColor
                )
            }
        }
        
        // Add tap gestures for specific tiles
        if tile.label == "Last Workout Completion" {
            tileView
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showWorkoutDetail = true
                    }
                }
        } else if tile.label == "Training Rhythm" {
            tileView
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRhythmDetail = true
                    }
                }
        } else {
            tileView
        }
    }
    
    private var workoutDetailView: some View {
        VStack(spacing: 0) {
            // Header
            workoutDetailHeader
            
            // Scrollable content with indicator
            ZStack(alignment: .bottom) {
                ScrollView {
                    workoutDetailContent
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30) // Extra space for scroll indicator
                }
                
                // Scroll indicator if content overflows
                if shouldShowScrollIndicator() {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
                                .padding(.bottom, 8)
                            Spacer()
                        }
                    }
                    .allowsHitTesting(false) // Don't intercept scroll gestures
                }
            }
        }
        .frame(height: 255 + 16) // 3 rows * 85px + spacing to match tiles height
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppStyle.Color.greenBlack.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale))
        .onTapGesture {
            // Prevent event bubbling - taps inside detail view should not close it
        }
    }
    
    private var workoutDetailHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWorkoutDetail = false
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppStyle.Color.greenGlow)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Last Workout")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)
                
                if let workoutDetail = viewModel.getLastTrainingDayWorkoutDetail() {
                    Text(DateFormatter.germanShort.string(from: workoutDetail.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
            }
            
            Spacer()
            
            // Empty space to center the title
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                Text("Back")
                    .font(.system(size: 14, weight: .medium))
            }
            .opacity(0) // Invisible but maintains spacing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var workoutDetailContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if let workoutDetail = viewModel.getLastTrainingDayWorkoutDetail() {
                ForEach(workoutDetail.categories, id: \.category) { categoryDetail in
                    categoryDetailSection(categoryDetail: categoryDetail)
                }
            } else {
                Text("No workout data available")
                    .font(.system(size: 14))
                    .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func categoryDetailSection(categoryDetail: CategoryDetailData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category name - same style as tiles
            Text(categoryDetail.category.displayName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppStyle.Color.greenGlow)
            
            // Exercises
            ForEach(categoryDetail.exercises, id: \.exercise.id) { exerciseDetail in
                exerciseDetailRow(exerciseDetail: exerciseDetail)
            }
        }
    }
    
    @ViewBuilder
    private func exerciseDetailRow(exerciseDetail: ExerciseDetailData) -> some View {
        HStack {
            Text(exerciseDetail.exercise.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppStyle.Color.greenGlow)
            
            Spacer()
            
            Text(exerciseDetail.isCompleted ? "Done" : "Not Started")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(exerciseDetail.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.greenGlow.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(exerciseDetail.isCompleted ? AppStyle.Color.greenGlow.opacity(0.2) : AppStyle.Color.greenGlow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppStyle.Color.greenGlow.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(.leading, 12)
    }
    
    private func shouldShowScrollIndicator() -> Bool {
        guard let workoutDetail = viewModel.getLastTrainingDayWorkoutDetail() else { return false }
        
        // Show indicator if there are many exercises (more than 4 total)
        let totalExercises = workoutDetail.categories.reduce(0) { total, category in
            total + category.exercises.count
        }
        
        return totalExercises > 4
    }
    
    private var rhythmDetailView: some View {
        VStack(spacing: 0) {
            // Header
            rhythmDetailHeader
            
            // Scrollable content with indicator
            ZStack(alignment: .bottom) {
                ScrollView {
                    rhythmDetailContent
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30) // Extra space for scroll indicator
                }
                
                // Scroll indicator if content overflows
                if shouldShowRhythmScrollIndicator() {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
                                .padding(.bottom, 8)
                            Spacer()
                        }
                    }
                    .allowsHitTesting(false) // Don't intercept scroll gestures
                }
            }
        }
        .frame(height: 255 + 16) // 3 rows * 85px + spacing to match tiles height
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppStyle.Color.greenBlack.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale))
        .onTapGesture {
            // Prevent event bubbling - taps inside detail view should not close it
        }
    }
    
    private var rhythmDetailHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRhythmDetail = false
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppStyle.Color.greenGlow)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Training Rhythm")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)
                
                if let rhythmDetail = viewModel.getTrainingRhythmDetail() {
                    Text(rhythmDetail.rhythmLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
            }
            
            Spacer()
            
            // Empty space to center the title
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                Text("Back")
                    .font(.system(size: 14, weight: .medium))
            }
            .opacity(0) // Invisible but maintains spacing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var rhythmDetailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let rhythmDetail = viewModel.getTrainingRhythmDetail() {
                
                // Training dates section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Letzte 5 Trainingstage")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppStyle.Color.greenGlow)
                    
                    ForEach(Array(rhythmDetail.trainingDates.enumerated()), id: \.offset) { index, date in
                        HStack {
                            Text(DateFormatter.germanMedium.string(from: date))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppStyle.Color.greenGlow)
                            
                            Spacer()
                            
                            if index < rhythmDetail.gaps.count - 1 { // Exclude the last gap (days since today)
                                let gap = rhythmDetail.gaps[index]
                                let dayText = gap == 1 ? "Day" : "Days"
                                Text("\(gap) \(dayText)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppStyle.Color.greenGlow.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(AppStyle.Color.greenGlow.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(AppStyle.Color.greenGlow.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        .padding(.leading, 12)
                    }
                    
                    // Add "Today" row with days since last training
                    if rhythmDetail.gaps.count > rhythmDetail.trainingDates.count - 1 {
                        HStack {
                            Text("Heute (\(DateFormatter.germanMedium.string(from: Date())))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppStyle.Color.greenGlow)
                            
                            Spacer()
                            
                            let daysSinceLastTraining = rhythmDetail.gaps.last ?? 0
                            let dayText = daysSinceLastTraining == 1 ? "day" : "days"
                            Text("Last training \(daysSinceLastTraining) \(dayText) ago")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(daysSinceLastTraining > 7 ? AppStyle.Color.yellow : AppStyle.Color.greenGlow.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill((daysSinceLastTraining > 7 ? AppStyle.Color.yellow : AppStyle.Color.greenGlow).opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke((daysSinceLastTraining > 7 ? AppStyle.Color.yellow : AppStyle.Color.greenGlow).opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.leading, 12)
                    }
                }
                
                // Explanation section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Berechnung")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppStyle.Color.greenGlow)
                    
                    Text(rhythmDetail.explanation)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppStyle.Color.greenGlow)
                        .padding(.leading, 12)
                        .lineSpacing(4)
                }
                
            } else {
                Text("Nicht genügend Trainingsdaten")
                    .font(.system(size: 14))
                    .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }
        }
        .padding(.top, 8)
    }
    
    private func shouldShowRhythmScrollIndicator() -> Bool {
        guard let rhythmDetail = viewModel.getTrainingRhythmDetail() else { return false }
        return rhythmDetail.trainingDates.count > 3 // Show if more than 3 dates
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
    


    

    
    // MARK: - Helper Functions
    

    
    private func formatDateShort(_ date: Date) -> String {
        return DateFormatter.germanVeryShort.string(from: date)
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
                return DateFormatter.germanCompact.string(from: date)
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        return WeightFormatter.format(weight)
    }
}
