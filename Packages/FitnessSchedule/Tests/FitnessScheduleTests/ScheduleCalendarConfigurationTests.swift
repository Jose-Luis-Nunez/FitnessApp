import Foundation
import Testing
@testable import FitnessSchedule

@Suite("Schedule calendar localization", .tags(.fast))
struct ScheduleCalendarConfigurationTests {
    @Test
    func weekdaySymbolsFollowExplicitLocale() {
        let english = ScheduleCalendarConfiguration.weekdaySymbols(
            locale: Locale(identifier: "en_US")
        )
        let german = ScheduleCalendarConfiguration.weekdaySymbols(
            locale: Locale(identifier: "de_DE")
        )

        #expect(english.map { String($0.prefix(2)) } == ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"])
        #expect(german.map { String($0.prefix(2)) } == ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
    }
}
