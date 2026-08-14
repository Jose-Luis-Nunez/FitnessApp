import Foundation

public struct WeightOptionsGenerator {
    public static let exerciseWeightOptions: [Double] = generateExerciseWeightOptions()
    public static let trainingWeightOptions: [Double] = generateTrainingWeightOptions()

    /// Typed `[Double]` weight options in kg, half-step (30, 30.5, 31, …).
    /// Consumers format these locale-agnostic values only at the label layer.
    public static let bodyWeightOptionsKg: [Double] = generateBodyWeightOptionsKg()

    /// Integer-only subset of `bodyWeightOptionsKg` (30, 31, 32, …) used when
    /// the UI's decimal toggle is off. Cached so toggling doesn't re-filter a
    /// 341-element array on every render.
    public static let bodyWeightOptionsKgIntegerOnly: [Double] =
        bodyWeightOptionsKg.filter { $0 == floor($0) }

    public static func generateTrainingWeightOptions() -> [Double] {
        (0...600).map { Double($0) * 0.5 }
    }

    public static func generateExerciseWeightOptions() -> [Double] {
        (0...360).map { Double($0) * 0.5 }
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
