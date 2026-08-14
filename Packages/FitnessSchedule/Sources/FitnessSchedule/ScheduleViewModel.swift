import Foundation
import Observation
import FitnessAnalytics
import FitnessCore

public struct WeekDay: Identifiable {
    public let id: Int
    public let date: Date
    public let isTrainingDay: Bool
}

public struct WeekSummaryData {
    public let calendarWeek: Int
    public let days: [WeekDay]
    public let totalExercises: Int
    public let trainingDayCount: Int
}

public struct StreakData {
    public let current: Int
    public let longest: Int
    public let rhythm: TrainingRhythm
}

@Observable
@MainActor
public final class ScheduleViewModel {
    public var trainingDaySet: Set<Date> = []
    public var datesWithData: Set<Date> = []
    public private(set) var materializedStreakData = StreakData(
        current: 0,
        longest: 0,
        rhythm: .notEnoughData
    )
    public private(set) var selectedWeekSummary = WeekSummaryData(
        calendarWeek: 0,
        days: [],
        totalExercises: 0,
        trainingDayCount: 0
    )
    public private(set) var selectedDayDetail: WorkoutDetailData?
    public private(set) var selectedDayExerciseCount = 0

    private let totalAnalyticsVM: TotalAnalyticsViewModel

    @ObservationIgnored private var cachedStreakData: StreakData?
    @ObservationIgnored private var cachedStreakReferenceDay: Date?
    @ObservationIgnored private var cachedTrainingDays: [Date]?
    @ObservationIgnored private var cachedWeekSummaries: [Date: WeekSummaryData] = [:]
    @ObservationIgnored private var canMaterializeSelection = false

    public init() {
        self.totalAnalyticsVM = TotalAnalyticsViewModel()
    }

    public init(totalAnalyticsVM: TotalAnalyticsViewModel) {
        self.totalAnalyticsVM = totalAnalyticsVM
    }

    public func reloadData(
        selectionDate: Date = Date(),
        streakReferenceDate: Date = Date()
    ) {
        cachedTrainingDays = nil
        cachedStreakData = nil
        cachedStreakReferenceDay = nil
        cachedWeekSummaries = [:]
        guard totalAnalyticsVM.refreshData() else {
            canMaterializeSelection = false
            trainingDaySet = []
            datesWithData = []
            materializedStreakData = StreakData(current: 0, longest: 0, rhythm: .notEnoughData)
            selectedWeekSummary = WeekSummaryData(
                calendarWeek: 0,
                days: [],
                totalExercises: 0,
                trainingDayCount: 0
            )
            selectedDayDetail = nil
            selectedDayExerciseCount = 0
            return
        }
        canMaterializeSelection = true
        trainingDaySet = Set(trainingDays())
        datesWithData = totalAnalyticsVM.allDatesWithData()
        materializedStreakData = streakData(referenceDate: streakReferenceDate)
        materializeSelection(for: selectionDate)
    }

    public func materializeSelection(for date: Date) {
        guard canMaterializeSelection else { return }
        selectedWeekSummary = weekSummary(for: date)
        selectedDayDetail = dayDetail(for: date)
        selectedDayExerciseCount = exerciseCountForDay(date)
    }

    // MARK: - Training Days

    public func trainingDays() -> [Date] {
        if let cached = cachedTrainingDays { return cached }
        let days = totalAnalyticsVM.getTrainingDays()
        cachedTrainingDays = days
        return days
    }

    // MARK: - Streak Calculation

    public func streakData(referenceDate: Date = Date()) -> StreakData {
        let referenceDay = Calendar.current.startOfDay(for: referenceDate)
        if let cached = cachedStreakData,
           cachedStreakReferenceDay == referenceDay {
            return cached
        }
        let days = trainingDays()
        let current = currentStreak(from: days, referenceDate: referenceDate)
        let longest = longestStreak(from: days)
        let rhythm = totalAnalyticsVM.getTrainingRhythm()
        let result = StreakData(current: current, longest: longest, rhythm: rhythm)
        cachedStreakData = result
        cachedStreakReferenceDay = referenceDay
        return result
    }

    private func currentStreak(from sortedDays: [Date], referenceDate: Date) -> Int {
        guard !sortedDays.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let eligibleDays = sortedDays.filter {
            calendar.startOfDay(for: $0) <= today
        }

        // Allow streak to end today or yesterday
        guard let last = eligibleDays.last else { return 0 }
        let diff = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        guard (0...1).contains(diff) else { return 0 }

        var streak = 1
        for i in stride(from: eligibleDays.count - 2, through: 0, by: -1) {
            let gap = calendar.dateComponents([.day], from: eligibleDays[i], to: eligibleDays[i + 1]).day ?? 0
            if gap == 1 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func longestStreak(from sortedDays: [Date]) -> Int {
        guard sortedDays.count >= 2 else { return sortedDays.count }
        let calendar = Calendar.current
        var best = 1
        var run = 1
        for i in 1..<sortedDays.count {
            let gap = calendar.dateComponents([.day], from: sortedDays[i - 1], to: sortedDays[i]).day ?? 0
            if gap == 1 {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    // MARK: - Week Summary

    public func weekSummary(for referenceDate: Date) -> WeekSummaryData {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? calendar.startOfDay(for: referenceDate)
        if let cached = cachedWeekSummaries[weekStart] { return cached }

        let weekOfYear = calendar.component(.weekOfYear, from: referenceDate)

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return WeekSummaryData(calendarWeek: weekOfYear, days: [], totalExercises: 0, trainingDayCount: 0)
        }

        let trainingDaySet = Set(trainingDays())
        let allEntries = totalAnalyticsVM.loadAllAnalytics()
        var days: [WeekDay] = []
        var totalExercises = 0
        var trainingCount = 0

        for offset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)

            let isTrained = trainingDaySet.contains(where: { calendar.isDate($0, inSameDayAs: dayStart) })
            let dayExerciseCount = Set(allEntries.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }.map(\.exerciseId)).count

            days.append(WeekDay(
                id: offset,
                date: dayStart,
                isTrainingDay: isTrained
            ))

            totalExercises += dayExerciseCount
            if isTrained { trainingCount += 1 }
        }

        let result = WeekSummaryData(
            calendarWeek: weekOfYear,
            days: days,
            totalExercises: totalExercises,
            trainingDayCount: trainingCount
        )
        cachedWeekSummaries[weekStart] = result
        return result
    }

    // MARK: - Day Detail

    public func dayDetail(for date: Date) -> WorkoutDetailData? {
        totalAnalyticsVM.getWorkoutDetail(for: date)
    }

    public func exerciseCountForDay(_ date: Date) -> Int {
        let entries = totalAnalyticsVM.loadAnalytics(for: date)
        return Set(entries.map(\.exerciseId)).count
    }
}
