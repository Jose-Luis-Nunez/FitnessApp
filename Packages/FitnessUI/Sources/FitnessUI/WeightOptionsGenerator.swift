import Foundation

public struct WeightOptionsGenerator {
    public static let exerciseWeightOptions: [String] = generateExerciseWeightOptions()
    public static let trainingWeightOptions: [String] = generateTrainingWeightOptions()

    /// Typed `[Double]` weight options in kg, half-step (30, 30.5, 31, …).
    /// Consumers that need a locale-agnostic source of truth (e.g. the Profile
    /// body-metrics wheel) should use this instead of the String-tagged
    /// `exerciseWeightOptions` so formatting stays at the label layer.
    public static let bodyWeightOptionsKg: [Double] = generateBodyWeightOptionsKg()

    /// Integer-only subset of `bodyWeightOptionsKg` (30, 31, 32, …) used when
    /// the UI's decimal toggle is off. Cached so toggling doesn't re-filter a
    /// 341-element array on every render.
    public static let bodyWeightOptionsKgIntegerOnly: [Double] =
        bodyWeightOptionsKg.filter { $0 == floor($0) }

    public static func generateTrainingWeightOptions() -> [String] {
        var options: [String] = []
        for i in 0...600 {
            let weight = Double(i) * 0.5
            if weight == floor(weight) {
                options.append("\(Int(weight))")
            } else {
                options.append(String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ","))
            }
        }
        return options
    }

    public static func generateExerciseWeightOptions() -> [String] {
        var options: [String] = []
        for i in 0...180 {
            options.append(String(i))
            if i < 180 {
                let halfValue = Double(i) + 0.5
                options.append(String(halfValue).replacingOccurrences(of: ".", with: ","))
            }
        }
        return options
    }

    /// Body weight range (30...200 kg) in half-step increments.
    private static func generateBodyWeightOptionsKg() -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(341)
        for i in 30...200 {
            values.append(Double(i))
            if i < 200 {
                values.append(Double(i) + 0.5)
            }
        }
        return values
    }
}
