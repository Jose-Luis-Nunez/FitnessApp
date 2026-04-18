import XCTest
@testable import FitnessCore

final class ExerciseFeedbackTests: XCTestCase {

    func testEmptyFeedbackHasNoContent() {
        let feedback = ExerciseFeedback(exerciseId: UUID())
        XCTAssertFalse(feedback.hasAnyContent)
    }

    func testEnergyLevelAloneCountsAsContent() {
        let feedback = ExerciseFeedback(exerciseId: UUID(), energyLevel: 3)
        XCTAssertTrue(feedback.hasAnyContent)
    }

    func testSymptomAloneCountsAsContent() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            symptoms: [.pain]
        )
        XCTAssertTrue(feedback.hasAnyContent)
    }

    func testNoteOnlyCountsAsContent() {
        let feedback = ExerciseFeedback(exerciseId: UUID(), note: "Rechte Schulter instabil")
        XCTAssertTrue(feedback.hasAnyContent)
    }

    func testEmptyNoteDoesNotCount() {
        let feedback = ExerciseFeedback(exerciseId: UUID(), note: "")
        XCTAssertFalse(feedback.hasAnyContent)
    }

    func testPainRegionsAloneCountAsContent() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            painRegions: [.lowerBack]
        )
        XCTAssertTrue(feedback.hasAnyContent)
    }

    func testMultiplePainRegionsArePersistedAsSet() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            painCategory: .back,
            painRegions: [.lowerBack, .upperBack, .shoulderLeft]
        )
        XCTAssertEqual(feedback.painRegions.count, 3)
        XCTAssertTrue(feedback.painRegions.contains(.lowerBack))
        XCTAssertTrue(feedback.painRegions.contains(.upperBack))
        XCTAssertTrue(feedback.painRegions.contains(.shoulderLeft))
    }

    func testEmptyPainRegionsDoNotCountAsContent() {
        let feedback = ExerciseFeedback(
            exerciseId: UUID(),
            painRegions: []
        )
        XCTAssertFalse(feedback.hasAnyContent)
    }
}
