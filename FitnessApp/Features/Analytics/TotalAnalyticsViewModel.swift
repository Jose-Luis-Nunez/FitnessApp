import Foundation

class TotalAnalyticsViewModel: ObservableObject {
    private let storageService: TotalAnalyticsStorageService
    
    init(storageService: TotalAnalyticsStorageService = TotalAnalyticsStorageService()) {
        self.storageService = storageService
    }
    
    // MARK: - Data Loading
    
    func loadAllAnalytics() -> [AnalyticsEntry] {
        return storageService.loadAllAnalytics()
    }
    
    func loadAnalytics(for date: Date) -> [AnalyticsEntry] {
        return storageService.loadAllAnalytics(for: date)
    }
    
    func getAllExercisesWithAnalytics() -> [Exercise] {
        return storageService.getAllExercisesWithAnalytics()
    }
    
    // MARK: - Statistics
    
    func totalWorkoutDaysInCurrentMonth() -> Int {
        let calendar = Calendar.current
        let allEntries = loadAllAnalytics()
        
        let currentMonthDates = allEntries
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .map { calendar.startOfDay(for: $0.date) }
        
        return Set(currentMonthDates).count
    }
    
    func totalExercisesCompleted() -> Int {
        return getAllExercisesWithAnalytics().count
    }
    
    func totalWeightIncreases() -> Int {
        let exercises = getAllExercisesWithAnalytics()
        var totalIncreases = 0
        
        for exercise in exercises {
            let entries = storageService.analyticsStorage.load(for: exercise.id)
            let calendar = Calendar.current
            
            // Get entries for current month
            let currentMonthEntries = entries
                .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                .sorted(by: { $0.date < $1.date })
            
            let dailyWeights: [(date: Date, weight: Double)] = currentMonthEntries.compactMap { entry in
                guard let weight = entry.setProgress.first?.weight else { return nil }
                let day = calendar.startOfDay(for: entry.date)
                return (date: day, weight: weight)
            }
            
            let maxWeightPerDay: [(date: Date, weight: Double)] = Dictionary(grouping: dailyWeights, by: { $0.date })
                .compactMap { (date, values) in
                    let maxWeight = values.map(\.weight).max() ?? 0.0
                    return (date, maxWeight)
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
    
    func allDatesWithData() -> Set<Date> {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current
        let uniqueDates = allEntries.map { calendar.startOfDay(for: $0.date) }
        return Set(uniqueDates)
    }
    
    func currentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: Date()).capitalized
    }
    
    func totalWorkoutDaysInYear() -> Int {
        let calendar = Calendar.current
        let allEntries = loadAllAnalytics()
        
        let currentYearDates = allEntries
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .year) }
            .map { calendar.startOfDay(for: $0.date) }
        
        return Set(currentYearDates).count
    }
    
    func averageExercisesPerSession() -> Int {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current
        
        // Group by date and count unique exercises per day
        let dailyExerciseCounts = Dictionary(grouping: allEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, entries) -> Int in
                let uniqueExercises = Set(entries.map { $0.exerciseId })
                return uniqueExercises.count
            }
        
        guard !dailyExerciseCounts.isEmpty else { return 0 }
        
        let totalExercises = dailyExerciseCounts.reduce(0, +)
        return totalExercises / dailyExerciseCounts.count
    }
    
    // MARK: - Recent Activity
    
    func getRecentWorkouts(limit: Int = 5) -> [(date: Date, exerciseCount: Int)] {
        let allEntries = loadAllAnalytics()
        let calendar = Calendar.current
        
        // Group by date and count unique exercises
        let dailyWorkouts = Dictionary(grouping: allEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, entries) -> (date: Date, exerciseCount: Int) in
                let uniqueExercises = Set(entries.map { $0.exerciseId })
                return (date: date, exerciseCount: uniqueExercises.count)
            }
            .sorted { $0.date > $1.date }
        
        return Array(dailyWorkouts.prefix(limit))
    }
    
    // MARK: - Progress Tracking
    
    func getExerciseProgressSummary() -> [ExerciseProgressSummary] {
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
    
    func getMostTrainedCategory() -> (category: MuscleCategoryGroup, count: Int) {
        let categoryData = getCategoryProgressData()
        
        let categoryWithMostExercises = categoryData.max { category1, category2 in
            category1.exerciseCount < category2.exerciseCount
        }
        
        if let mostTrained = categoryWithMostExercises, mostTrained.exerciseCount > 0 {
            return (category: mostTrained.category, count: mostTrained.exerciseCount)
        }
        
        return (category: .arms, count: 0) // Default fallback
    }
    
    func getLeastTrainedCategory() -> (category: MuscleCategoryGroup, count: Int) {
        let categoryData = getCategoryProgressData()
        let categoriesWithData = categoryData.filter { $0.exerciseCount > 0 }
        
        let categoryWithLeastExercises = categoriesWithData.min { category1, category2 in
            category1.exerciseCount < category2.exerciseCount
        }
        
        if let leastTrained = categoryWithLeastExercises {
            return (category: leastTrained.category, count: leastTrained.exerciseCount)
        }
        
        return (category: .arms, count: 0) // Default fallback
    }
    
    func getCategoryWithMostImprovements() -> (category: MuscleCategoryGroup, improvements: Int) {
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
        
        return (category: .arms, improvements: 0) // Default fallback
    }
    
    func getCategoryWithMostWeightGains() -> (category: MuscleCategoryGroup, totalGains: Double) {
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
        
        return (category: .arms, totalGains: 0.0) // Default fallback
    }
    
    func getCategoryProgressData() -> [CategoryProgressData] {
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
                
                // Calculate actual weight increments and total gains
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
    
    // MARK: - Helper Functions
    
    private func calculateWeightProgress(entries: [AnalyticsEntry]) -> (increments: Int, totalGains: Double) {
        guard entries.count > 1 else { return (0, 0.0) }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        var increments = 0
        var totalGains: Double = 0.0
        var previousWeight: Double = 0
        
        for entry in sortedEntries {
            if let weight = entry.setProgress.first?.weight {
                if previousWeight > 0 && weight > previousWeight {
                    let weightGain = weight - previousWeight
                    // Ignore unrealistic jumps (more than 50kg at once)
                    if weightGain <= 50.0 {
                        increments += 1
                        totalGains += weightGain
                    }
                }
                previousWeight = weight
            }
        }
        
        return (increments, totalGains)
    }
    
    // MARK: - Improvement Frequency Chart Data
    
    func getFrequencyMilestones() -> [(date: Date, frequency: Double)] {
        let allData = getCategoryProgressData()
        let allExercises = allData.flatMap { $0.exercises }
        
        guard !allExercises.isEmpty else { return [] }
        
        // Collect all frequency milestones from all exercises
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
                    // Check if this is an improvement
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
        
        // Sort by date and return
        return allMilestones.sorted { $0.date < $1.date }
    }
    
    func getExerciseFrequencyHistory(for exerciseId: UUID) -> [(weight: Double, frequency: Double)] {
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
                    
                    // Add data point at each weight increase
                    let currentFrequency = Double(sessionsCount) / Double(improvementsCount)
                    weightFrequencyData.append((
                        weight: weight,
                        frequency: currentFrequency
                    ))
                }
                previousWeight = weight
            }
        }
        
        // If we don't have enough weight progression data, create synthetic weight points
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
        let estimatedSteps = max(2, Int(weightRange / 5)) // Every 5kg or at least 2 steps
        
        for step in 0..<estimatedSteps {
            let weightProgress = Double(step) / Double(estimatedSteps - 1)
            let currentWeight = startWeight + (weightRange * weightProgress)
            
            // Frequency tends to increase as weight gets higher (takes more sessions per improvement)
            let baseFrequency = 1.5
            let progressionFactor = 0.5 * weightProgress // Gets harder over time
            let frequency = baseFrequency + progressionFactor
            
            syntheticData.append((
                weight: currentWeight,
                frequency: frequency
            ))
        }
        
        return syntheticData
    }
    
    private func createSyntheticFrequencyData(from entries: [AnalyticsEntry]) -> [(date: Date, frequency: Double)] {
        // Create a more gradual frequency curve based on session progression
        var syntheticData: [(date: Date, frequency: Double)] = []
        let totalSessions = entries.count
        
        // Calculate theoretical improvements (more conservative)
        let estimatedImprovements = max(1, totalSessions / 3) // Assume improvement every 3 sessions
        
        for (index, entry) in entries.enumerated() {
            let sessionNumber = index + 1
            let progressRatio = Double(sessionNumber) / Double(totalSessions)
            
            // Create a more realistic frequency curve
            let currentImprovements = max(1, Int(Double(estimatedImprovements) * progressRatio))
            let frequency = Double(sessionNumber) / Double(currentImprovements)
            
            syntheticData.append((
                date: entry.date,
                frequency: frequency
            ))
        }
        
        return syntheticData
    }
    

}

// MARK: - Category Helper Models

struct CategoryProgressData {
    let category: MuscleCategoryGroup
    let exercises: [ExerciseProgressData]
    
    var exerciseCount: Int {
        return exercises.count
    }
    
    var totalWeightIncrease: Double {
        return exercises.reduce(0) { $0 + ($1.currentWeight - $1.initialWeight) }
    }
}

struct ExerciseProgressData {
    let exercise: Exercise
    let initialWeight: Double
    let currentWeight: Double
    let sessionsCount: Int
    let startDate: Date
    let weightIncrements: Int // Number of actual weight increases
    let totalWeightGains: Double // Total KG gained from all weight increases
    
    var weightDifference: Double {
        return currentWeight - initialWeight
    }
    
    var weightPercentage: Double {
        guard initialWeight > 0 else { return 0 }
        return ((currentWeight - initialWeight) / initialWeight) * 100
    }
    
    var improvementFrequency: Double {
        guard weightIncrements > 0 else { return 0 }
        return Double(sessionsCount) / Double(weightIncrements)
    }
}

// MARK: - Helper Models

struct ExerciseProgressSummary {
    let exercise: Exercise
    let currentWeight: Double
    let startingWeight: Double
    let totalSessions: Int
    let lastWorkoutDate: Date
    
    var weightProgress: Double {
        return currentWeight - startingWeight
    }
    
    var progressPercentage: Double {
        guard startingWeight > 0 else { return 0 }
        return ((currentWeight - startingWeight) / startingWeight) * 100
    }
}

// MARK: - Chart Models

struct ImprovementFrequencyPoint {
    let date: Date
    let frequency: Double // Sessions per improvement (lower = better)
    let exerciseCount: Int
}
