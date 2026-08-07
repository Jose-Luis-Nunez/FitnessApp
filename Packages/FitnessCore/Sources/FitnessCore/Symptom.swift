import Foundation

public enum Symptom: String, CaseIterable, Identifiable, Codable, Sendable {
    case pain
    case dizziness
    case nausea
    case muscleWeakness

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pain:            return "Pain"
        case .dizziness:       return "Dizziness"
        case .nausea:          return "Nausea"
        case .muscleWeakness:  return "Weakness"
        }
    }

    public var description: String {
        switch self {
        case .pain:            return "Acute or sharp"
        case .dizziness:       return "Lightheaded / spinning"
        case .nausea:          return "Upset stomach / Fatigue"
        case .muscleWeakness:  return "Inability to hold form"
        }
    }
}
