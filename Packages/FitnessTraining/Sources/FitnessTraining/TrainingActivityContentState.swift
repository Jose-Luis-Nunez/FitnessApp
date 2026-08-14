import Foundation
import FitnessResources

/// Stable, testable payload shared by the app's ActivityKit bridge and widget.
///
/// Keeping the payload in the training package avoids making pure Codable and
/// localization tests build the complete host application.
public struct TrainingActivityContentState: Codable, Hashable, Sendable {
    public var exerciseName: String
    public var currentSet: Int
    public var totalSets: Int
    public var reps: Int
    public var weight: Double
    public var isFinished: Bool
    public var languageCode: String?

    public init(
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        reps: Int,
        weight: Double,
        isFinished: Bool,
        languageCode: String? = nil
    ) {
        self.exerciseName = exerciseName
        self.currentSet = currentSet
        self.totalSets = totalSets
        self.reps = reps
        self.weight = weight
        self.isFinished = isFinished
        self.languageCode = languageCode
    }

    public var language: AppLanguage {
        AppLanguage.resolving(languageCode: languageCode)
    }

    public func localized(_ resource: LocalizedStringResource) -> String {
        AppText.resolve(resource, locale: language.locale)
    }
}
