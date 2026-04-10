import Foundation
import FitnessCore

/// Mirrors app navigation destinations for use when hosting exercise feature from SPM.
public enum NavigationDestination: Hashable {
    case home
    case profile
    case totalAnalytics
    case schedule
    case muscleCategory(MuscleCategoryGroup)
    case training(Exercise, MuscleCategoryGroup)
}
