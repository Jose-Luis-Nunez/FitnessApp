import Foundation

public struct WeightFormatter {
    public static func format(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        } else {
            return String(weight).replacingOccurrences(of: ".", with: ",")
        }
    }

    public static func displayWeight(_ weight: Double) -> String {
        "\(format(weight)) kg"
    }

    public static func parse(_ weightString: String) -> Double? {
        let normalized = weightString.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    public static func formatGoalForInput(_ goal: Double) -> String {
        if goal == floor(goal) {
            return "\(Int(goal))"
        } else {
            return String(goal).replacingOccurrences(of: ".", with: ",")
        }
    }
}
