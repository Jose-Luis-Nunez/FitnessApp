import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessUI
import Factory

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
    public let trainingDates: [Date]
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
        self.trainingDates = trainingDates
        self.gaps = gaps
        self.averageGap = averageGap
        self.rhythmLabel = rhythmLabel
        self.explanation = explanation
    }
}

@Observable
@MainActor
public final class TotalAnalyticsViewModel {
    @ObservationIgnored @Injected(\.totalAnalyticsStorage) private var storageService
    @ObservationIgnored @Injected(\.workoutStorage) private var workoutStorage
    @ObservationIgnored @Injected(\.exerciseStorage) private var exerciseStorage

    nonisolated public init() {
    }

    // MARK: - Data Loading

    public func loadAllAnalytics() -> [AnalyticsEntry] {
        return storageService.loadAllAnalytics()
    }

    public func loadAnalytics(for date: Date) -> [AnalyticsEntry] {
        return storageService.loadAllAnalytics(for: date)
    }

    public func getAllExercisesWithAnalytics() -> [Exercise] {
        return storageService.getAllExercisesWithAnalytics()
    }

    // MARK: - Statistics

    public func totalWorkoutDaysInCurrentMonth() -> Int {
        AnalyticsDateHelper.daysInCurrentMonth(from: loadAllAnalytics().map(\.date))
    }

    public func totalExercisesCompleted() -> Int {
        return getAllExercisesWithAnalytics().count
    }

    public func totalWeightIncreases() -> Int {
        let exercises = getAllExercisesWithAnalytics()
        let calendar = Calendar.current
        var totalIncreases = 0

        for exercise in exercises {
            let entries = storageService.analyticsStorage.load(for: exercise.id)

            let maxWeightPerDay: [(date: Date, weight: Double)] = Dictionary(
                grouping: entries,
                by: { calendar.startOfDay(for: $0.date) }
            )
            .compactMap { (date, dayEntries) in
                let maxWeight = dayEntries.flatMap { $0.setProgress.map(\.weight) }.max() ?? 0.0
                return maxWeight > 0 ? (date, maxWeight) : nil
            }
            .sorted(by: { $0.date < $1.date })

            var lastWeight: Double? = nil
            for (_, weight) in maxWeightPerDay {
                if let previous = lastWeight {
                    if weight > previous {
                        totalIncreases += 1
                    }
                }
                lastWeight = weight
            }
        }

        return totalIncreases
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

    public func averageExercisesPerSession() -> Int {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current

        let dailyExerciseCounts = Dictionary(grouping: allEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (_, entries) -> Int in
                let uniqueExercises = Set(entries.map { $0.exerciseId })
                return uniqueExercises.count
            }

        guard !dailyExerciseCounts.isEmpty else { return 0 }

        let totalExercises = dailyExerciseCounts.reduce(0, +)
        return totalExercises / dailyExerciseCounts.count
    }

    // MARK: - Recent Activity

    public func getRecentWorkouts(limit: Int = 5) -> [(date: Date, exerciseCount: Int)] {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current

        let dailyWorkouts = Dictionary(grouping: allEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, entries) -> (date: Date, exerciseCount: Int) in
                let uniqueExercises = Set(entries.map { $0.exerciseId })
                return (date: date, exerciseCount: uniqueExercises.count)
            }
            .sorted { $0.date > $1.date }

        return Array(dailyWorkouts.prefix(limit))
    }

    // MARK: - Progress Tracking

    public func getExerciseProgressSummary() -> [ExerciseProgressSummary] {
        let exercises = getAllExercisesWithAnalytics()
        return exercises.compactMap { exercise in
            let entries = storageService.analyticsStorage.load(for: exercise.id)
            guard let latestEntry = entries.max(by: { $0.date < $1.date }),
                  let currentWeight = latestEntry.setProgress.first?.weight else {
                return nil
            }

            let firstEntry = entries.min(by: { $0.date < $1.date })
            let startingWeight = firstEntry?.setProgress.first?.weight ?? currentWeight

            return ExerciseProgressSummary(
                exercise: exercise,
                currentWeight: currentWeight,
                startingWeight: startingWeight,
                totalSessions: entries.count,
                lastWorkoutDate: latestEntry.date
            )
        }.sorted { $0.exercise.name < $1.exercise.name }
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

    public func getCategoryWithMostWeightGains() -> (category: MuscleCategoryGroup, totalGains: Double) {
        let categoryData = getCategoryProgressData()

        let categoryWeightGains = categoryData.map { categoryData in
            let totalWeightGains = categoryData.exercises.reduce(0.0) { total, exercise in
                total + exercise.totalWeightGains
            }
            return (category: categoryData.category, totalGains: totalWeightGains)
        }

        let categoryWithMostWeightGains = categoryWeightGains.max { category1, category2 in
            category1.totalGains < category2.totalGains
        }

        if let mostWeightGains = categoryWithMostWeightGains, mostWeightGains.totalGains > 0 {
            return mostWeightGains
        }

        return (category: .arms, totalGains: 0.0)
    }

    public func getCategoryProgressData() -> [CategoryProgressData] {
        let exercises = getAllExercisesWithAnalytics()
        let categories: [MuscleCategoryGroup] = [.arms, .abs, .back, .legs, .chest]

        return categories.map { category in
            let categoryExercises = exercises.filter { $0.category == category }
            let exerciseProgressData = categoryExercises.compactMap { exercise -> ExerciseProgressData? in
                let entries = storageService.analyticsStorage.load(for: exercise.id)
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

        var allExercises: [Exercise] = []

        for category in MuscleCategoryGroup.allCases {
            let categoryExercises = exerciseStorage.loadForWorkout(workoutId: currentWorkout.id, category: category)
            allExercises.append(contentsOf: categoryExercises)
        }

        guard !allExercises.isEmpty else {
            return (completed: 0, total: 0, percentage: 0)
        }

        let calendar = Calendar.current
        let completedExercises = allExercises.filter { exercise in
            let entries = storageService.analyticsStorage.load(for: exercise.id)
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

        for category in MuscleCategoryGroup.allCases {
            let categoryExercises = exerciseStorage.loadForWorkout(workoutId: currentWorkout.id, category: category)

            guard !categoryExercises.isEmpty else { continue }

            let exerciseDetails = categoryExercises.map { exercise in
                let entries = storageService.analyticsStorage.load(for: exercise.id)
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
        let lastTrainingDay = recentTrainingDays.last!
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

        return "Historische Abstände: \(gapsText) Days\nDurchschnitt: \(roundedAverage) Days\nSeit letztem Training: \(daysSinceLastTraining) Days (nicht in Berechnung)\nErgebnis: \(rhythmLabel)"
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

    // MARK: - Improvement Frequency Chart Data

    public func getFrequencyMilestones() -> [(date: Date, frequency: Double)] {
        let allData = getCategoryProgressData()
        let allExercises = allData.flatMap { $0.exercises }

        guard !allExercises.isEmpty else { return [] }

        var allMilestones: [(date: Date, frequency: Double)] = []

        for exerciseData in allExercises {
            let entries = storageService.analyticsStorage.load(for: exerciseData.exercise.id)
            guard entries.count > 1 else { continue }

            let sortedEntries = entries.sorted { $0.date < $1.date }
            var sessionsCount = 0
            var improvementsCount = 0
            var previousWeight: Double = 0

            for entry in sortedEntries {
                sessionsCount += 1

                if let weight = entry.setProgress.first?.weight {
                    if previousWeight > 0 && weight > previousWeight {
                        improvementsCount += 1
                        let currentFrequency = Double(sessionsCount) / Double(improvementsCount)

                        allMilestones.append((
                            date: entry.date,
                            frequency: currentFrequency
                        ))
                    }
                    previousWeight = weight
                }
            }
        }

        return allMilestones.sorted { $0.date < $1.date }
    }

    public func getExerciseFrequencyHistory(for exerciseId: UUID) -> [(weight: Double, frequency: Double)] {
        let entries = storageService.analyticsStorage.load(for: exerciseId)
        guard entries.count >= 2 else { return [] }

        let sortedEntries = entries.sorted { $0.date < $1.date }
        var weightFrequencyData: [(weight: Double, frequency: Double)] = []
        var sessionsCount = 0
        var improvementsCount = 0
        var previousWeight: Double = 0

        for entry in sortedEntries {
            sessionsCount += 1

            if let weight = entry.setProgress.first?.weight {
                if previousWeight > 0 && weight > previousWeight {
                    improvementsCount += 1

                    let currentFrequency = Double(sessionsCount) / Double(improvementsCount)
                    weightFrequencyData.append((
                        weight: weight,
                        frequency: currentFrequency
                    ))
                }
                previousWeight = weight
            }
        }

        if weightFrequencyData.count < 2 && entries.count >= 3 {
            return createSyntheticWeightFrequencyData(from: sortedEntries)
        }

        return weightFrequencyData
    }

    private func createSyntheticWeightFrequencyData(from entries: [AnalyticsEntry]) -> [(weight: Double, frequency: Double)] {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        guard !sortedEntries.isEmpty else { return [] }

        let weights = sortedEntries.compactMap { $0.setProgress.first?.weight }
        guard !weights.isEmpty else { return [] }

        let startWeight = weights.first ?? 0
        let endWeight = weights.last ?? startWeight
        let weightRange = endWeight - startWeight

        var syntheticData: [(weight: Double, frequency: Double)] = []
        let estimatedSteps = max(2, Int(weightRange / 5))

        for step in 0..<estimatedSteps {
            let weightProgress = Double(step) / Double(estimatedSteps - 1)
            let currentWeight = startWeight + (weightRange * weightProgress)

            let baseFrequency = 1.5
            let progressionFactor = 0.5 * weightProgress
            let frequency = baseFrequency + progressionFactor

            syntheticData.append((
                weight: currentWeight,
                frequency: frequency
            ))
        }

        return syntheticData
    }
}

// MARK: - Category Helper Models

public struct CategoryProgressData {
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

public struct ExerciseProgressData {
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

// MARK: - Helper Models

public struct ExerciseProgressSummary {
    public let exercise: Exercise
    public let currentWeight: Double
    public let startingWeight: Double
    public let totalSessions: Int
    public let lastWorkoutDate: Date

    public init(
        exercise: Exercise,
        currentWeight: Double,
        startingWeight: Double,
        totalSessions: Int,
        lastWorkoutDate: Date
    ) {
        self.exercise = exercise
        self.currentWeight = currentWeight
        self.startingWeight = startingWeight
        self.totalSessions = totalSessions
        self.lastWorkoutDate = lastWorkoutDate
    }

    public var weightProgress: Double {
        return currentWeight - startingWeight
    }

    public var progressPercentage: Double {
        guard startingWeight > 0 else { return 0 }
        return ((currentWeight - startingWeight) / startingWeight) * 100
    }
}
