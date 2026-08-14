import Foundation

public enum Symptom: String, CaseIterable, Identifiable, Codable, Sendable {
    case pain
    case dizziness
    case nausea
    case muscleWeakness

    public var id: String { rawValue }
}
