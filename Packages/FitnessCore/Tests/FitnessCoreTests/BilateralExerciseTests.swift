import Foundation
import Testing
@testable import FitnessCore

@Suite("Bilateral exercise domain")
struct BilateralExerciseTests {
    @Test("Legacy exercise JSON defaults to standard mode")
    func legacyExerciseDefaultsToStandard() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Curl",
          "weight": 20,
          "reps": 12,
          "sets": 3,
          "noSeats": true,
          "isCompleted": false,
          "iconName": "defaultArmsIcon",
          "category": "arms",
          "isActive": true
        }
        """

        let decoded = try JSONDecoder().decode(Exercise.self, from: Data(json.utf8))

        #expect(decoded.executionMode == .standard)
        #expect(decoded.trainingSteps.count == 3)
        #expect(decoded.trainingSteps.allSatisfy { $0.side == nil })
    }

    @Test("Bilateral exercise encodes and creates pairwise steps")
    func bilateralRoundTripAndSteps() throws {
        let exercise = Exercise(
            name: "Torso",
            weight: 25,
            reps: 12,
            sets: 3,
            iconName: "defaultAbsIcon",
            category: .abs,
            executionMode: .bilateral
        )

        let decoded = try JSONDecoder().decode(
            Exercise.self,
            from: JSONEncoder().encode(exercise)
        )

        #expect(decoded.executionMode == .bilateral)
        #expect(decoded.trainingSteps.map(\.logicalSetIndex) == [0, 0, 1, 1, 2, 2])
        #expect(decoded.trainingSteps.map(\.side) == [.left, .right, .left, .right, .left, .right])
    }

    @Test("Legacy set progress remains valid without side")
    func legacySetProgressDefaultsToNoSide() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "status": "completedDone",
          "currentReps": 12,
          "weight": 20
        }
        """

        let decoded = try JSONDecoder().decode(SetProgress.self, from: Data(json.utf8))

        #expect(decoded.side == nil)
        #expect(decoded.logicalSetIndex == nil)
    }

    @Test("Set progress preserves side metadata")
    func setProgressMetadataRoundTrips() throws {
        let progress = SetProgress(
            status: .completedMore,
            currentReps: 13,
            weight: 22.5,
            side: .right,
            logicalSetIndex: 2
        )

        let decoded = try JSONDecoder().decode(
            SetProgress.self,
            from: JSONEncoder().encode(progress)
        )

        #expect(decoded.side == .right)
        #expect(decoded.logicalSetIndex == 2)
        #expect(decoded.currentReps == 13)
    }

    @Test("Set progress transitions preserve identity and bilateral metadata")
    func setProgressTransitionPreservesIdentityAndMetadata() {
        let id = UUID()
        let progress = SetProgress(
            id: id,
            status: .inProgress,
            currentReps: 12,
            weight: 20,
            side: .right,
            logicalSetIndex: 1
        )

        let transitioned = progress.transitioned(
            to: .completedMore,
            currentReps: 14,
            weight: 22.5
        )

        #expect(transitioned.id == id)
        #expect(transitioned.status == .completedMore)
        #expect(transitioned.currentReps == 14)
        #expect(transitioned.weight == 22.5)
        #expect(transitioned.side == .right)
        #expect(transitioned.logicalSetIndex == 1)
    }
}
