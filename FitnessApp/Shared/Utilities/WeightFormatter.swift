import Foundation

/// Utility for formatting and parsing weight values with German locale conventions
struct WeightFormatter {
    
    /// Formats a weight value for display using German decimal separator (comma)
    /// - Parameter weight: The weight value to format
    /// - Returns: Formatted string (e.g., "65" for 65.0, "67,5" for 67.5)
    static func format(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        } else {
            return String(weight).replacingOccurrences(of: ".", with: ",")
        }
    }
    
    /// Formats a weight value with "kg" suffix
    /// - Parameter weight: The weight value to format
    /// - Returns: Formatted string with kg suffix (e.g., "65kg", "67,5kg")
    static func formatWithUnit(_ weight: Double) -> String {
        return "\(format(weight))kg"
    }
    
    /// Parses a weight string with German decimal separator to Double
    /// - Parameter weightString: String representation of weight (with comma as decimal separator)
    /// - Returns: Parsed Double value or nil if parsing fails
    static func parse(_ weightString: String) -> Double? {
        let normalized = weightString.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    /// Formats a goal value for input fields using German decimal separator
    /// - Parameter goal: The goal value to format
    /// - Returns: Formatted string for input display
    static func formatGoalForInput(_ goal: Double) -> String {
        if goal == floor(goal) {
            return "\(Int(goal))"
        } else {
            return String(goal).replacingOccurrences(of: ".", with: ",")
        }
    }
}
