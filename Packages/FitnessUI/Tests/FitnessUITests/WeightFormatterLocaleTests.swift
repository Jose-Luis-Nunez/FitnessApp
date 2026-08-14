import Foundation
import Testing
@testable import FitnessUI

@Suite("Weight formatter locales")
struct WeightFormatterLocaleTests {
    @Test func formatsDecimalSeparatorForEnglishAndGerman() {
        #expect(WeightFormatter.format(20.5, locale: Locale(identifier: "en_US")) == "20.5")
        #expect(WeightFormatter.format(20.5, locale: Locale(identifier: "de_DE")) == "20,5")
        #expect(WeightFormatter.format(20.25, locale: Locale(identifier: "en_US")) == "20.25")
        #expect(WeightFormatter.format(20.25, locale: Locale(identifier: "de_DE")) == "20,25")
    }

    @Test func parsesDotAndCommaRegardlessOfPresentationLocale() {
        #expect(WeightFormatter.parse("20.5") == 20.5)
        #expect(WeightFormatter.parse("20,5") == 20.5)
    }
}
