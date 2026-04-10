import Foundation

public enum AnalyticsDateHelper {
    public static func currentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: Date()).capitalized
    }

    public static func uniqueDays(from dates: [Date]) -> Set<Date> {
        let calendar = Calendar.current
        return Set(dates.map { calendar.startOfDay(for: $0) })
    }

    public static func daysInCurrentMonth(from dates: [Date]) -> Int {
        let calendar = Calendar.current
        let monthDates = dates
            .filter { calendar.isDate($0, equalTo: Date(), toGranularity: .month) }
            .map { calendar.startOfDay(for: $0) }
        return Set(monthDates).count
    }
}
