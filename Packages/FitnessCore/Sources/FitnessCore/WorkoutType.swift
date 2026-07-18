/// User-selected presentation type for a workout.
///
/// This is stored independently from the workout name so artwork selection
/// remains stable when the user enters a custom name or renames the workout.
public enum WorkoutType: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case pull
    case push
    case leg
    case individual
    case full

    public var id: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = WorkoutType(rawValue: rawValue) ?? .individual
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
