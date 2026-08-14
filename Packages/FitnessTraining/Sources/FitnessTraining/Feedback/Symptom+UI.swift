import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

/// UI-layer mapping from a domain `Symptom` to its visual accent colour. The
/// extension lives in `FitnessTraining` (not `FitnessCore`) because tying a
/// domain enum to `Color` would force the domain layer to depend on `SwiftUI`
/// — a one-way coupling we deliberately avoid.
extension Symptom {
    public var localizedName: LocalizedStringResource {
        switch self {
        case .pain: AppText.feedbackPain
        case .dizziness: AppText.feedbackDizziness
        case .nausea: AppText.feedbackNausea
        case .muscleWeakness: AppText.feedbackWeakness
        }
    }

    public var localizedDescription: LocalizedStringResource {
        switch self {
        case .pain: AppText.feedbackPainDetail
        case .dizziness: AppText.feedbackDizzinessDetail
        case .nausea: AppText.feedbackNauseaDetail
        case .muscleWeakness: AppText.feedbackWeaknessDetail
        }
    }

    public func iconColor(in theme: AppColorTheme) -> Color {
        switch self {
        case .pain:           return AppStyle.Color.symptomPain
        case .dizziness:      return AppStyle.Color.symptomDizziness
        case .nausea:         return theme.accent.nausea
        case .muscleWeakness: return AppStyle.Color.symptomWeakness
        }
    }
}

extension BodyRegion {
    public var localizedName: LocalizedStringResource {
        switch self {
        case .neckLeft: AppText.bodyRegionNeckLeft
        case .neckRight: AppText.bodyRegionNeckRight
        case .shoulderLeft: AppText.bodyRegionShoulderLeft
        case .shoulderRight: AppText.bodyRegionShoulderRight
        case .upperBack: AppText.bodyRegionUpperBack
        case .middleBack: AppText.bodyRegionMiddleBack
        case .lowerBack: AppText.bodyRegionLowerBack
        case .abs: AppText.bodyRegionAbs
        case .obliquesLeft: AppText.bodyRegionObliquesLeft
        case .obliquesRight: AppText.bodyRegionObliquesRight
        case .chestLeft: AppText.bodyRegionChestLeft
        case .chestRight: AppText.bodyRegionChestRight
        case .bicepsLeft: AppText.bodyRegionBicepsLeft
        case .bicepsRight: AppText.bodyRegionBicepsRight
        case .tricepsLeft: AppText.bodyRegionTricepsLeft
        case .tricepsRight: AppText.bodyRegionTricepsRight
        case .forearmLeft: AppText.bodyRegionForearmLeft
        case .forearmRight: AppText.bodyRegionForearmRight
        case .handLeft: AppText.bodyRegionHandLeft
        case .handRight: AppText.bodyRegionHandRight
        case .wristLeft: AppText.bodyRegionWristLeft
        case .wristRight: AppText.bodyRegionWristRight
        case .thighFront: AppText.bodyRegionThighFront
        case .thighBack: AppText.bodyRegionThighBack
        case .thighInner: AppText.bodyRegionThighInner
        case .thighOuter: AppText.bodyRegionThighOuter
        case .kneeLeft: AppText.bodyRegionKneeLeft
        case .kneeRight: AppText.bodyRegionKneeRight
        case .calf: AppText.bodyRegionCalf
        case .foot: AppText.bodyRegionFoot
        case .ankle: AppText.bodyRegionAnkle
        }
    }
}
