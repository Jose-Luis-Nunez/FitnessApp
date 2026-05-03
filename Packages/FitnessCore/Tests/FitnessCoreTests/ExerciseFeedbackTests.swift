import Testing
import Foundation
@testable import FitnessCore

@Suite("ExerciseFeedback")
struct ExerciseFeedbackTests {

    @Test func emptyFeedbackHasNoContent() {
        let feedback = ExerciseFeedback(exerciseId: UUID())
        #expect(!feedback.hasAnyContent)
    }

    @Test func energyLevelAloneCountsAsContent() {
        let feedback = ExerciseFeedback(exerciseId: UUID(), energyLevel: 3)
        #expect(feedback.hasAnyContent)
    }

    @Test func symptomAloneCountsAsContent() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            symptoms: [.pain]
        )
        #expect(feedback.hasAnyContent)
    }

    @Test func noteOnlyCountsAsContent() {
        let feedback = ExerciseFeedback(exerciseId: UUID(), note: "Rechte Schulter instabil")
        #expect(feedback.hasAnyContent)
    }

    @Test func emptyNoteDoesNotCount() {
        let feedback = ExerciseFeedback(exerciseId: UUID(), note: "")
        #expect(!feedback.hasAnyContent)
    }

    @Test func painRegionsAloneCountAsContent() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            painRegions: [.lowerBack]
        )
        #expect(feedback.hasAnyContent)
    }

    @Test func multiplePainRegionsArePersistedAsSet() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            painCategory: .back,
            painRegions: [.lowerBack, .upperBack, .shoulderLeft]
        )
        #expect(feedback.painRegions.count == 3)
        #expect(feedback.painRegions.contains(.lowerBack))
        #expect(feedback.painRegions.contains(.upperBack))
        #expect(feedback.painRegions.contains(.shoulderLeft))
    }

    @Test func emptyPainRegionsDoNotCountAsContent() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            painRegions: []
        )
        #expect(!feedback.hasAnyContent)
    }
}
