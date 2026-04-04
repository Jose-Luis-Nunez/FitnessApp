import Foundation

// MARK: - Weight Options Generator
struct WeightOptionsGenerator {
    
    static let exerciseWeightOptions: [String] = generateExerciseWeightOptions()
    static let trainingWeightOptions: [String] = generateTrainingWeightOptions()
    
    /// Generate weight options for training picker (0-300kg with 0.5 increments)
    static func generateTrainingWeightOptions() -> [String] {
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
    
    /// Generate weight options for exercise picker (0-180kg with 0.5 increments)
    static func generateExerciseWeightOptions() -> [String] {
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
    
    /// Generate weight options with custom range
    static func generateWeightOptions(maxWeight: Int = 300, includeHalfSteps: Bool = true) -> [String] {
        var options: [String] = []
        let maxIterations = includeHalfSteps ? maxWeight * 2 : maxWeight
        
        for i in 0...maxIterations {
            if includeHalfSteps {
                let weight = Double(i) * 0.5
                if weight == floor(weight) {
                    options.append("\(Int(weight))")
                } else {
                    options.append(String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ","))
                }
            } else {
                options.append(String(i))
            }
        }
        return options
    }
}
