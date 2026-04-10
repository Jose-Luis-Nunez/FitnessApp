import Foundation
import FitnessAnalytics
import FitnessCore
import FitnessStorage

public struct WeekDay: Identifiable {
    public let id: Int
    public let date: Date
    public let label: String
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
    public let rhythmLabel: String
}

public class ScheduleViewModel: ObservableObject {
    @Published public var trainingDaySet: Set<Date> = []
    @Published public var datesWithData: Set<Date> = []

    private let totalAnalyticsVM: TotalAnalyticsViewModel

    public init(totalAnalyticsVM: TotalAnalyticsViewModel = TotalAnalyticsViewModel()) {
        self.totalAnalyticsVM = totalAnalyticsVM
        reloadData()
    }

    public func reloadData() {
        trainingDaySet = Set(totalAnalyticsVM.getTrainingDays())
        datesWithData = totalAnalyticsVM.allDatesWithData()
    }

    // MARK: - Training Days

    public func trainingDays() -> [Date] {
        totalAnalyticsVM.getTrainingDays()
    }

    public func allDatesWithData() -> Set<Date> {
        totalAnalyticsVM.allDatesWithData()
    }

    // MARK: - Streak Calculation

    public func streakData() -> StreakData {
        let days = trainingDays()
        let current = currentStreak(from: days)
        let longest = longestStreak(from: days)
        let rhythm = totalAnalyticsVM.getTrainingRhythm()
        return StreakData(current: current, longest: longest, rhythmLabel: rhythm)
    }

    private func currentStreak(from sortedDays: [Date]) -> Int {
        guard !sortedDays.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Allow streak to end today or yesterday
        guard let last = sortedDays.last else { return 0 }
        let diff = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        guard diff <= 1 else { return 0 }

        var streak = 1
        for i in stride(from: sortedDays.count - 2, through: 0, by: -1) {
            let gap = calendar.dateComponents([.day], from: sortedDays[i], to: sortedDays[i + 1]).day ?? 0
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
        let weekOfYear = calendar.component(.weekOfYear, from: referenceDate)

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return WeekSummaryData(calendarWeek: weekOfYear, days: [], totalExercises: 0, trainingDayCount: 0)
        }

        let trainingDaySet = Set(trainingDays())
        let allEntries = totalAnalyticsVM.loadAllAnalytics()
        let shortSymbols = germanWeekdaySymbols()

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
                label: shortSymbols[offset],
                isTrainingDay: isTrained
            ))

            totalExercises += dayExerciseCount
            if isTrained { trainingCount += 1 }
        }

        return WeekSummaryData(
            calendarWeek: weekOfYear,
            days: days,
            totalExercises: totalExercises,
            trainingDayCount: trainingCount
        )
    }

    private func germanWeekdaySymbols() -> [String] {
        ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
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
