import SwiftUI
import FitnessCore
import FitnessUI

/// UI-layer mapping from a domain `Symptom` to its visual accent colour. The
/// extension lives in `FitnessTraining` (not `FitnessCore`) because tying a
/// domain enum to `Color` would force the domain layer to depend on `SwiftUI`
/// — a one-way coupling we deliberately avoid.
extension Symptom {
    public var iconColor: Color {
        switch self {
        case .pain:           return AppStyle.Color.symptomPain
        case .dizziness:      return AppStyle.Color.symptomDizziness
        case .nausea:         return AppStyle.Color.symptomNausea
        case .muscleWeakness: return AppStyle.Color.symptomWeakness
        }
    }
}
