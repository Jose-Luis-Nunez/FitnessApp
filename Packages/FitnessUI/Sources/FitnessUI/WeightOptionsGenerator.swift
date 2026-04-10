import Foundation

public struct WeightOptionsGenerator {
    public static let exerciseWeightOptions: [String] = generateExerciseWeightOptions()
    public static let trainingWeightOptions: [String] = generateTrainingWeightOptions()

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
}
