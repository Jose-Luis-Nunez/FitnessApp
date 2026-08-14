import Foundation
import FitnessResources

public extension TrainingRhythm {
    var localizedResource: LocalizedStringResource {
        switch self {
        case .notEnoughData: AppText.commonNotEnoughData
        case .weekly: AppText.analyticsWeekly
        case .biweekly: AppText.analyticsBiweekly
        case .weeks(let count): AppText.analyticsWeeks(count: count)
        }
    }
}
