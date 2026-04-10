import FitnessCore
import FitnessStorage
import FitnessUI
import SwiftUI

// MARK: - Analytics Tile Data Model

public struct AnalyticsTileData: Identifiable {
    public let id: UUID
    public let type: TileType
    public let value: String
    public let label: String

    public enum TileType {
        case number
        case text
    }

    public init(id: UUID = UUID(), type: TileType, value: String, label: String) {
        self.id = id
        self.type = type
        self.value = value
        self.label = label
    }
}

public struct TotalAnalyticsView: View {
    @ObservedObject public var viewModel: TotalAnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var showCalendarDialog: Bool = false
    @State private var showWorkoutDetail: Bool = false
    @State private var showRhythmDetail: Bool = false

    @State private var datesWithData: Set<Date> = []

    public init(viewModel: TotalAnalyticsViewModel = TotalAnalyticsViewModel()) {
        self.viewModel = viewModel
    }

    public var body: some View {
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

                overallStatsView
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.vertical, 12)

                categoryProgressView
                    .padding(.vertical, 8)

                Spacer()
            }
            .frame(minHeight: geometry.size.height)
        }
        .onTapGesture {
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

                    if let currentWorkout = WorkoutStorageService.shared.currentWorkout {
                        Text("Workout: \(currentWorkout.name)")
                            .font(AppStyle.Font.detailCaption)
                            .foregroundColor(AppStyle.Color.greenGlow.opacity(0.8))
                    }
                }

                Spacer()

                Button(action: {
                    showCalendarDialog = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(AppStyle.Font.detailCaption)
                        Text(DateFormatter.germanShort.string(from: selectedDate))
                            .font(AppStyle.Font.detailCaption)
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
                label: "Training \(viewModel.currentMonthName())"
            ),
            AnalyticsTileData(
                type: .number,
                value: "\(viewModel.totalWorkoutDaysInYear())",
                label: "Training \(Calendar.current.component(.year, from: Date()))"
            ),
            AnalyticsTileData(
                type: .number,
                value: "\(completionRate.percentage)%",
                label: "Last Workout Completion"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(viewModel.getTrainingRhythm())",
                label: "Training Rhythm"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(mostTrained.category.displayName)",
                label: "Category with most exercise"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(leastTrained.category.displayName)",
                label: "Category with least exercise"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(mostImproved.category.displayName)",
                label: "Category with most Improvements"
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
                    label: tile.label
                )
            case .text:
                AnalyticsTileTextView(
                    text: tile.value,
                    label: tile.label
                )
            }
        }

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
        AnalyticsDetailSection(shouldShowIndicator: shouldShowScrollIndicator()) {
            AnalyticsDetailHeader(
                title: "Last Workout",
                subtitle: viewModel.getLastTrainingDayWorkoutDetail().map { DateFormatter.germanShort.string(from: $0.date) },
                onBack: { showWorkoutDetail = false }
            )
        } content: {
            workoutDetailContent
        }
    }

    private var workoutDetailContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if let workoutDetail = viewModel.getLastTrainingDayWorkoutDetail() {
                ForEach(workoutDetail.categories, id: \.category) { categoryDetail in
                    categoryDetailSection(categoryDetail: categoryDetail)
                }
            } else {
                Text("No workout data available")
                    .font(AppStyle.Font.pickerAction)
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
            Text(categoryDetail.category.displayName)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(AppStyle.Color.greenGlow)

            ForEach(categoryDetail.exercises, id: \.exercise.id) { exerciseDetail in
                exerciseDetailRow(exerciseDetail: exerciseDetail)
            }
        }
    }

    @ViewBuilder
    private func exerciseDetailRow(exerciseDetail: ExerciseDetailData) -> some View {
        HStack {
            Text(exerciseDetail.exercise.name)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.greenGlow)

            Spacer()

            Text(exerciseDetail.isCompleted ? "Done" : "Not Started")
                .font(AppStyle.Font.detailCaption)
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

        let totalExercises = workoutDetail.categories.reduce(0) { total, category in
            total + category.exercises.count
        }

        return totalExercises > 4
    }

    private var rhythmDetailView: some View {
        AnalyticsDetailSection(shouldShowIndicator: shouldShowRhythmScrollIndicator()) {
            AnalyticsDetailHeader(
                title: "Training Rhythm",
                subtitle: viewModel.getTrainingRhythmDetail()?.rhythmLabel,
                onBack: { showRhythmDetail = false }
            )
        } content: {
            rhythmDetailContent
        }
    }

    private var rhythmDetailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let rhythmDetail = viewModel.getTrainingRhythmDetail() {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Letzte 5 Trainingstage")
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(AppStyle.Color.greenGlow)

                    ForEach(Array(rhythmDetail.trainingDates.enumerated()), id: \.offset) { index, date in
                        HStack {
                            Text(DateFormatter.germanMedium.string(from: date))
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(AppStyle.Color.greenGlow)

                            Spacer()

                            if index < rhythmDetail.gaps.count - 1 {
                                let gap = rhythmDetail.gaps[index]
                                let dayText = gap == 1 ? "Day" : "Days"
                                Text("\(gap) \(dayText)")
                                    .font(AppStyle.Font.detailCaption)
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

                    if rhythmDetail.gaps.count > rhythmDetail.trainingDates.count - 1 {
                        HStack {
                            Text("Heute (\(DateFormatter.germanMedium.string(from: Date())))")
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(AppStyle.Color.greenGlow)

                            Spacer()

                            let daysSinceLastTraining = rhythmDetail.gaps.last ?? 0
                            let dayText = daysSinceLastTraining == 1 ? "day" : "days"
                            Text("Last training \(daysSinceLastTraining) \(dayText) ago")
                                .font(AppStyle.Font.detailCaption)
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Berechnung")
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(AppStyle.Color.greenGlow)

                    Text(rhythmDetail.explanation)
                        .font(AppStyle.Font.detailExercise)
                        .foregroundColor(AppStyle.Color.greenGlow)
                        .padding(.leading, 12)
                        .lineSpacing(4)
                }

            } else {
                Text("Nicht genügend Trainingsdaten")
                    .font(AppStyle.Font.pickerAction)
                    .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }
        }
        .padding(.top, 8)
    }

    private func shouldShowRhythmScrollIndicator() -> Bool {
        guard let rhythmDetail = viewModel.getTrainingRhythmDetail() else { return false }
        return rhythmDetail.trainingDates.count > 3
    }

    private var categoryProgressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(AppStyle.Font.analyticsExerciseData)
                .foregroundColor(AppStyle.Color.white)
                .padding(.horizontal, AppStyle.Padding.horizontal)

            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        let categoryData = viewModel.getCategoryProgressData()
                        let cardWidth = geometry.size.width * 0.90 - (AppStyle.Padding.horizontal * 2)

                        ForEach(Array(categoryData.enumerated()), id: \.offset) { _, data in
                            categoryCard(data: data)
                                .frame(width: cardWidth)
                                .frame(height: 300)
                        }
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
            .frame(height: 320)
        }
    }

    private func categoryCard(data: CategoryProgressData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category: \(data.category.displayName)")
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)

                Spacer()

                Text("\(data.exerciseCount) exercise\(data.exerciseCount == 1 ? "" : "s")")
                    .font(AppStyle.Font.calendarSubheader)
                    .foregroundColor(AppStyle.Color.greenGlow)
            }
            .frame(height: 30)

            if data.exercises.isEmpty {
                VStack {
                    Spacer()
                    Text("No training")
                        .font(AppStyle.Font.pickerAction)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(data.exercises.enumerated()), id: \.offset) { _, exerciseData in
                                exerciseProgressRow(data: exerciseData)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if data.exercises.count > 3 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(AppStyle.Font.chartAxisSmall)
                                    .foregroundColor(AppStyle.Color.white.opacity(0.5))
                                    .padding(.bottom, 4)
                                Spacer()
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func exerciseProgressRow(data: ExerciseProgressData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.exercise.name)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.white)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start")
                        .font(AppStyle.Font.chartLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    HStack(spacing: 4) {
                        Text("\(formatWeight(data.initialWeight)) kg")
                            .font(AppStyle.Font.detailCaption)
                            .foregroundColor(AppStyle.Color.white)
                        Text("(\(formatDateShort(data.startDate)))")
                            .font(AppStyle.Font.chartAxisSmall)
                            .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Current")
                        .font(AppStyle.Font.chartLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    Text("\(formatWeight(data.currentWeight)) kg")
                        .font(AppStyle.Font.detailCaption)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Progress")
                        .font(AppStyle.Font.chartLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))

                    let difference = data.weightDifference
                    let percentage = data.weightPercentage
                    let frequency = data.improvementFrequency

                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 2) {
                            if difference > 0 {
                                Text("+\(formatWeight(difference)) kg")
                                    .font(AppStyle.Font.cardSmallMedium)
                                    .foregroundColor(AppStyle.Color.green)
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(AppStyle.Font.analyticsAxis)
                                    .foregroundColor(AppStyle.Color.green.opacity(0.7))
                            } else if difference < 0 {
                                Text("\(formatWeight(difference)) kg")
                                    .font(AppStyle.Font.cardSmallMedium)
                                    .foregroundColor(.red)
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(AppStyle.Font.analyticsAxis)
                                    .foregroundColor(.red.opacity(0.7))
                            } else {
                                Text("0 kg")
                                    .font(AppStyle.Font.cardSmallMedium)
                                    .foregroundColor(AppStyle.Color.white.opacity(0.6))
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(AppStyle.Font.analyticsAxis)
                                    .foregroundColor(AppStyle.Color.white.opacity(0.4))
                            }
                        }

                        if percentage != 0 {
                            Text(percentage > 0 ? "+\(Int(percentage))%" : "\(Int(percentage))%")
                                .font(AppStyle.Font.analyticsAxis)
                                .foregroundColor(percentage > 0 ? AppStyle.Color.green.opacity(0.8) : .red.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDateShort(_ date: Date) -> String {
        return DateFormatter.germanVeryShort.string(from: date)
    }

    private func formatWeight(_ weight: Double) -> String {
        return WeightFormatter.format(weight)
    }
}
