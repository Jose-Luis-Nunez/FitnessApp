import Foundation

public struct WeightFormatter {
    public static func format(
        _ weight: Double,
        locale: Locale
    ) -> String {
        return weight.formatted(
            .number
                .precision(.fractionLength(0...2))
                .locale(locale)
        )
    }

    public static func displayWeight(
        _ weight: Double,
        locale: Locale
    ) -> String {
        "\(format(weight, locale: locale)) kg"
    }

    /// Input deliberately accepts both decimal separators independent of the
    /// selected display language, preserving existing data and habits.
    public static func parse(_ weightString: String) -> Double? {
        let normalized = weightString.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    public static func formatGoalForInput(
        _ goal: Double,
        locale: Locale
    ) -> String {
        format(goal, locale: locale)
    }
}
