import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessUI
import Factory
import os

private let logger = Logger(subsystem: "FitnessAnalytics", category: "TotalAnalyticsViewModel")

// MARK: - Workout Detail Data Models

public struct WorkoutDetailData {
    public let date: Date
    public let categories: [CategoryDetailData]

    public init(date: Date, categories: [CategoryDetailData]) {
        self.date = date
        self.categories = categories
    }
}

public struct CategoryDetailData {
    public let category: MuscleCategoryGroup
    public let exercises: [ExerciseDetailData]

    public init(category: MuscleCategoryGroup, exercises: [ExerciseDetailData]) {
        self.category = category
        self.exercises = exercises
    }
}

public struct ExerciseDetailData {
    public let exercise: Exercise
    public let isCompleted: Bool

    public init(exercise: Exercise, isCompleted: Bool) {
        self.exercise = exercise
        self.isCompleted = isCompleted
    }
}

// MARK: - Training Rhythm Detail Data Models

public struct TrainingRhythmDetailData {
    public let trainingDates: [IdentifiableDate]
    public let gaps: [Int]
    public let averageGap: Double
    public let rhythmLabel: String
    public let explanation: String

    public init(
        trainingDates: [Date],
        gaps: [Int],
        averageGap: Double,
        rhythmLabel: String,
        explanation: String
    ) {
        self.trainingDates = trainingDates.enumerated().map { IdentifiableDate(index: $0.offset, date: $0.element) }
        self.gaps = gaps
        self.averageGap = averageGap
        self.rhythmLabel = rhythmLabel
        self.explanation = explanation
    }
}

public struct IdentifiableDate: Identifiable {
    public let id: Int
    public let date: Date

    public init(index: Int, date: Date) {
        self.id = index
        self.date = date
    }
}

public struct TotalAnalyticsDisplayState {
    public let datesWithData: Set<Date>
    public let categoryProgress: [CategoryProgressData]
    public let workoutDetail: WorkoutDetailData?
    public let rhythmDetail: TrainingRhythmDetailData?
    public let tiles: [AnalyticsTileData]

    public static let empty = TotalAnalyticsDisplayState(
        datesWithData: [],
        categoryProgress: [],
        workoutDetail: nil,
        rhythmDetail: nil,
        tiles: []
    )
}

@Observable
@MainActor
public final class TotalAnalyticsViewModel {
    public private(set) var displayState: TotalAnalyticsDisplayState = .empty
    @ObservationIgnored private let storageService: TotalAnalyticsStoring
    @ObservationIgnored private let workoutStorage: WorkoutStoring

    // MARK: - Cached Data

    @ObservationIgnored private var cachedCategoryProgress: [CategoryProgressData]?
    @ObservationIgnored private var cachedSnapshot: WorkoutAnalyticsSnapshot?

    public init(
        totalAnalyticsStorage: TotalAnalyticsStoring? = nil,
        workoutStorage: WorkoutStoring? = nil
    ) {
        self.storageService = totalAnalyticsStorage ?? Container.shared.totalAnalyticsStorage()
        self.workoutStorage = workoutStorage ?? Container.shared.workoutStorage()
    }

    /// Atomically replaces the current workout snapshot. A failed refresh keeps
    /// the previous snapshot only when it belongs to the same workout.
    @discardableResult
    public func refreshData() -> Bool {
        guard let workoutId = workoutStorage.currentWorkout?.id else {
            clearCachedData()
            return true
        }

        let canKeepCurrentSnapshot = cachedSnapshot?.workoutId == workoutId
        do {
            cache(try storageService.loadSnapshot(for: workoutId))
            return true
        } catch {
            logger.error("Failed to refresh analytics snapshot for workout \(workoutId): \(error)")
            if !canKeepCurrentSnapshot {
                clearCachedData()
            }
            return canKeepCurrentSnapshot
        }
    }

    public func materializeDisplayState(now: Date = Date()) {
        guard refreshData() else {
            displayState = .empty
            return
        }
        let mostTrained = getMostTrainedCategory()
        let leastTrained = getLeastTrainedCategory()
        let mostImproved = getCategoryWithMostImprovements()
        let completionRate = getLastTrainingDayCompletionRate()
        displayState = TotalAnalyticsDisplayState(
            datesWithData: allDatesWithData(),
            categoryProgress: getCategoryProgressData(),
            workoutDetail: getLastTrainingDayWorkoutDetail(),
            rhythmDetail: getTrainingRhythmDetail(),
            tiles: [
                AnalyticsTileData(
                    kind: .currentMonthTraining,
                    type: .number,
                    value: "\(totalWorkoutDaysInCurrentMonth())",
                    label: "Training \(currentMonthName())"
                ),
                AnalyticsTileData(
                    kind: .currentYearTraining,
                    type: .number,
                    value: "\(totalWorkoutDaysInYear())",
                    label: "Training \(Calendar.current.component(.year, from: now))"
                ),
                AnalyticsTileData(
                    kind: .lastWorkoutCompletion,
                    type: .number,
                    value: "\(completionRate.percentage)%",
                    label: "Last Workout Completion"
                ),
                AnalyticsTileData(
                    kind: .trainingRhythm,
                    type: .text,
                    value: getTrainingRhythm(),
                    label: "Training Rhythm"
                ),
                AnalyticsTileData(
                    kind: .mostTrainedCategory,
                    type: .text,
                    value: mostTrained.category.displayName,
                    label: "Category with most exercise"
                ),
                AnalyticsTileData(
                    kind: .leastTrainedCategory,
                    type: .text,
                    value: leastTrained.category.displayName,
                    label: "Category with least exercise"
                ),
                AnalyticsTileData(
                    kind: .mostImprovedCategory,
                    type: .text,
                    value: mostImproved.category.displayName,
                    label: "Category with most Improvements"
                ),
            ]
        )
    }

    // MARK: - Data Loading

    public func loadAllAnalytics() -> [AnalyticsEntry] {
        workoutSnapshot()?.entries ?? []
    }

    private func workoutSnapshot() -> WorkoutAnalyticsSnapshot? {
        guard let workoutId = workoutStorage.currentWorkout?.id else {
            clearCachedData()
            return nil
        }
        if let cachedSnapshot, cachedSnapshot.workoutId == workoutId {
            return cachedSnapshot
        }

        clearCachedData()
        do {
            let snapshot = try storageService.loadSnapshot(for: workoutId)
            cache(snapshot)
            return snapshot
        } catch {
            logger.error("Failed to load analytics snapshot for workout \(workoutId): \(error)")
            return nil
        }
    }

    private func cache(_ snapshot: WorkoutAnalyticsSnapshot) {
        cachedSnapshot = snapshot
        cachedCategoryProgress = nil
    }

    private func clearCachedData() {
        cachedSnapshot = nil
        cachedCategoryProgress = nil
    }

    public func loadAnalytics(for date: Date) -> [AnalyticsEntry] {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func getAllExercisesWithAnalytics() -> [Exercise] {
        guard let snapshot = workoutSnapshot() else { return [] }
        return snapshot.exercises.filter {
            !(snapshot.entriesByExerciseId[$0.id] ?? []).isEmpty
        }
    }

    // MARK: - Statistics

    public func totalWorkoutDaysInCurrentMonth() -> Int {
        AnalyticsDateHelper.daysInCurrentMonth(from: loadAllAnalytics().map(\.date))
    }

    public func allDatesWithData() -> Set<Date> {
        AnalyticsDateHelper.uniqueDays(from: loadAllAnalytics().map(\.date))
    }

    public func currentMonthName() -> String {
        AnalyticsDateHelper.currentMonthName()
    }

    public func totalWorkoutDaysInYear() -> Int {
        let calendar = Calendar.current
        let allEntries = loadAllAnalytics()

        let currentYearDates = allEntries
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .year) }
            .map { calendar.startOfDay(for: $0.date) }

        return Set(currentYearDates).count
    }

    // MARK: - Category Analysis

    public func getMostTrainedCategory() -> (category: MuscleCategoryGroup, count: Int) {
        let categoryData = getCategoryProgressData()

        let categoryWithMostExercises = categoryData.max { category1, category2 in
            category1.exerciseCount < category2.exerciseCount
        }

        if let mostTrained = categoryWithMostExercises, mostTrained.exerciseCount > 0 {
            return (category: mostTrained.category, count: mostTrained.exerciseCount)
        }

        return (category: .arms, count: 0)
    }

    public func getLeastTrainedCategory() -> (category: MuscleCategoryGroup, count: Int) {
        let categoryData = getCategoryProgressData()
        let categoriesWithData = categoryData.filter { $0.exerciseCount > 0 }

        let categoryWithLeastExercises = categoriesWithData.min { category1, category2 in
            category1.exerciseCount < category2.exerciseCount
        }

        if let leastTrained = categoryWithLeastExercises {
            return (category: leastTrained.category, count: leastTrained.exerciseCount)
        }

        return (category: .arms, count: 0)
    }

    public func getCategoryWithMostImprovements() -> (category: MuscleCategoryGroup, improvements: Int) {
        let categoryData = getCategoryProgressData()

        let categoryImprovements = categoryData.map { categoryData in
            let totalImprovements = categoryData.exercises.reduce(0) { total, exercise in
                total + exercise.weightIncrements
            }
            return (category: categoryData.category, improvements: totalImprovements)
        }

        let categoryWithMostImprovements = categoryImprovements.max { category1, category2 in
            category1.improvements < category2.improvements
        }

        if let mostImproved = categoryWithMostImprovements, mostImproved.improvements > 0 {
            return mostImproved
        }

        return (category: .arms, improvements: 0)
    }

    public func getCategoryProgressData() -> [CategoryProgressData] {
        if let cached = cachedCategoryProgress { return cached }

        let exercises = getAllExercisesWithAnalytics()
        let categories: [MuscleCategoryGroup] = [.arms, .abs, .back, .legs, .chest]

        let result = categories.map { category in
            let categoryExercises = exercises.filter { $0.category == category }
            let exerciseProgressData = categoryExercises.compactMap { exercise -> ExerciseProgressData? in
                let entries = workoutSnapshot()?.entries(for: exercise.id) ?? []
                guard !entries.isEmpty else { return nil }

                let sortedEntries = entries.sorted { $0.date < $1.date }
                let firstWeight = sortedEntries.first?.setProgress.first?.weight ?? 0
                let lastWeight = sortedEntries.last?.setProgress.first?.weight ?? 0
                let firstDate = sortedEntries.first?.date ?? Date()

                let weightProgress = calculateWeightProgress(entries: sortedEntries)

                return ExerciseProgressData(
                    exercise: exercise,
                    initialWeight: firstWeight,
                    currentWeight: lastWeight,
                    sessionsCount: entries.count,
                    startDate: firstDate,
                    weightIncrements: weightProgress.increments,
                    totalWeightGains: weightProgress.totalGains
                )
            }

            return CategoryProgressData(
                category: category,
                exercises: exerciseProgressData
            )
        }

        cachedCategoryProgress = result
        return result
    }

    // MARK: - Workout Completion Analysis

    public func getLastTrainingDayCompletionRate() -> (completed: Int, total: Int, percentage: Int) {
        let trainingDays = getTrainingDays()
        guard let lastTrainingDay = trainingDays.last else {
            return (completed: 0, total: 0, percentage: 0)
        }

        return getWorkoutCompletionRate(for: lastTrainingDay)
    }

    private func getWorkoutCompletionRate(for date: Date) -> (completed: Int, total: Int, percentage: Int) {
        guard let currentWorkout = workoutStorage.currentWorkout else {
            return (completed: 0, total: 0, percentage: 0)
        }

        guard let snapshot = workoutSnapshot(), snapshot.workoutId == currentWorkout.id else {
            return (completed: 0, total: 0, percentage: 0)
        }
        let allExercises = snapshot.exercises

        guard !allExercises.isEmpty else {
            return (completed: 0, total: 0, percentage: 0)
        }

        let calendar = Calendar.current
        let completedExercises = allExercises.filter { exercise in
            let entries = snapshot.entries(for: exercise.id)
            return entries.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: date)
            }
        }

        let totalCount = allExercises.count
        let completedCount = completedExercises.count
        let percentage = totalCount > 0 ? Int(round(Double(completedCount) / Double(totalCount) * 100)) : 0

        return (completed: completedCount, total: totalCount, percentage: percentage)
    }

    public func getLastTrainingDayWorkoutDetail() -> WorkoutDetailData? {
        let trainingDays = getTrainingDays()
        guard let lastTrainingDay = trainingDays.last else { return nil }

        return getWorkoutDetail(for: lastTrainingDay)
    }

    public func getWorkoutDetail(for date: Date) -> WorkoutDetailData? {
        guard let currentWorkout = workoutStorage.currentWorkout else { return nil }

        let calendar = Calendar.current
        var categoryDetails: [CategoryDetailData] = []
        guard let snapshot = workoutSnapshot(), snapshot.workoutId == currentWorkout.id else {
            return nil
        }

        for category in MuscleCategoryGroup.allCases {
            let categoryExercises = snapshot.exercises.filter { $0.category == category }

            guard !categoryExercises.isEmpty else { continue }

            let exerciseDetails = categoryExercises.map { exercise in
                let entries = snapshot.entries(for: exercise.id)
                let isCompleted = entries.contains { entry in
                    calendar.isDate(entry.date, inSameDayAs: date)
                }
                return ExerciseDetailData(exercise: exercise, isCompleted: isCompleted)
            }

            categoryDetails.append(CategoryDetailData(category: category, exercises: exerciseDetails))
        }

        return WorkoutDetailData(date: date, categories: categoryDetails)
    }

    // MARK: - Training Rhythm Analysis

    public func getTrainingRhythm() -> String {
        let trainingDays = getTrainingDays()
        return calculateTrainingRhythm(from: trainingDays)
    }

    public func getTrainingRhythmDetail() -> TrainingRhythmDetailData? {
        let trainingDays = getTrainingDays()
        guard trainingDays.count >= 2 else { return nil }

        let recentTrainingDays = Array(trainingDays.suffix(5))
        guard recentTrainingDays.count >= 2 else { return nil }

        let gaps = calculateDayGaps(between: recentTrainingDays)
        guard !gaps.isEmpty else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let lastTrainingDay = recentTrainingDays.last else { return nil }
        let daysSinceLastTraining = calendar.dateComponents([.day], from: lastTrainingDay, to: today).day ?? 0

        let extendedGaps = gaps + [daysSinceLastTraining]

        let averageGap = Double(gaps.reduce(0, +)) / Double(gaps.count)
        let rhythmLabel = formatTrainingRhythm(averageGap: averageGap)

        let explanation = createRhythmExplanation(
            gaps: gaps,
            daysSinceLastTraining: daysSinceLastTraining,
            averageGap: averageGap,
            rhythmLabel: rhythmLabel
        )

        return TrainingRhythmDetailData(
            trainingDates: recentTrainingDays,
            gaps: extendedGaps,
            averageGap: averageGap,
            rhythmLabel: rhythmLabel,
            explanation: explanation
        )
    }

    private func createRhythmExplanation(gaps: [Int], daysSinceLastTraining: Int, averageGap: Double, rhythmLabel: String) -> String {
        let gapsText = gaps.map { "\($0)" }.joined(separator: ", ")
        let roundedAverage = String(format: "%.1f", averageGap)

        return "Historical gaps: \(gapsText) Days\nAverage: \(roundedAverage) Days\nSince last training: \(daysSinceLastTraining) Days (not in calculation)\nResult: \(rhythmLabel)"
    }

    public func getTrainingDays() -> [Date] {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current

        let dailyExerciseCounts = Dictionary(grouping: allEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, entries) -> (date: Date, exerciseCount: Int) in
                let uniqueExercises = Set(entries.map { $0.exerciseId })
                return (date: date, exerciseCount: uniqueExercises.count)
            }

        let trainingDays = dailyExerciseCounts
            .filter { $0.exerciseCount >= 3 }
            .map { $0.date }
            .sorted()

        return trainingDays
    }

    private func calculateTrainingRhythm(from trainingDays: [Date]) -> String {
        guard trainingDays.count >= 2 else {
            return "Not enough data"
        }

        let recentTrainingDays = Array(trainingDays.suffix(5))
        guard recentTrainingDays.count >= 2 else {
            return "Not enough data"
        }

        let gaps = calculateDayGaps(between: recentTrainingDays)
        guard !gaps.isEmpty else {
            return "Not enough data"
        }

        let averageGap = Double(gaps.reduce(0, +)) / Double(gaps.count)

        return formatTrainingRhythm(averageGap: averageGap)
    }

    private func calculateDayGaps(between dates: [Date]) -> [Int] {
        guard dates.count >= 2 else { return [] }

        let calendar = Calendar.current
        var gaps: [Int] = []

        for i in 1..<dates.count {
            let previousDate = dates[i - 1]
            let currentDate = dates[i]
            let daysBetween = calendar.dateComponents([.day], from: previousDate, to: currentDate).day ?? 0
            gaps.append(daysBetween)
        }

        return gaps
    }

    private func formatTrainingRhythm(averageGap: Double) -> String {
        if averageGap <= 7.0 {
            return "Weekly"
        } else if averageGap <= 14.0 {
            return "Biweekly"
        } else {
            let weeks = Int(round(averageGap / 7.0))
            return "\(weeks) weeks"
        }
    }

    // MARK: - Helper Functions

    private func calculateWeightProgress(entries: [AnalyticsEntry]) -> (increments: Int, totalGains: Double) {
        guard entries.count > 1 else { return (0, 0.0) }
        let calendar = Calendar.current

        let maxWeightPerDay = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, dayEntries) -> (date: Date, weight: Double)? in
                let maxWeight = dayEntries.flatMap { $0.setProgress.map(\.weight) }.max() ?? 0.0
                return maxWeight > 0 ? (date, maxWeight) : nil
            }
            .sorted(by: { $0.date < $1.date })

        var increments = 0
        var totalGains: Double = 0.0
        var previousWeight: Double = 0

        for (_, weight) in maxWeightPerDay {
            if previousWeight > 0 && weight > previousWeight {
                let weightGain = weight - previousWeight
                increments += 1
                totalGains += weightGain
            }
            previousWeight = weight
        }

        return (increments, totalGains)
    }
}

// MARK: - Category Helper Models

public struct CategoryProgressData: Identifiable {
    public var id: String { category.rawValue }
    public let category: MuscleCategoryGroup
    public let exercises: [ExerciseProgressData]

    public init(category: MuscleCategoryGroup, exercises: [ExerciseProgressData]) {
        self.category = category
        self.exercises = exercises
    }

    public var exerciseCount: Int {
        return exercises.count
    }

    public var totalWeightIncrease: Double {
        return exercises.reduce(0) { $0 + ($1.currentWeight - $1.initialWeight) }
    }
}

public struct ExerciseProgressData: Identifiable {
    public var id: UUID { exercise.id }
    public let exercise: Exercise
    public let initialWeight: Double
    public let currentWeight: Double
    public let sessionsCount: Int
    public let startDate: Date
    public let weightIncrements: Int
    public let totalWeightGains: Double

    public init(
        exercise: Exercise,
        initialWeight: Double,
        currentWeight: Double,
        sessionsCount: Int,
        startDate: Date,
        weightIncrements: Int,
        totalWeightGains: Double
    ) {
        self.exercise = exercise
        self.initialWeight = initialWeight
        self.currentWeight = currentWeight
        self.sessionsCount = sessionsCount
        self.startDate = startDate
        self.weightIncrements = weightIncrements
        self.totalWeightGains = totalWeightGains
    }

    public var weightDifference: Double {
        return currentWeight - initialWeight
    }

    public var weightPercentage: Double {
        guard initialWeight > 0 else { return 0 }
        return ((currentWeight - initialWeight) / initialWeight) * 100
    }

    public var improvementFrequency: Double {
        guard weightIncrements > 0 else { return 0 }
        return Double(sessionsCount) / Double(weightIncrements)
    }
}
