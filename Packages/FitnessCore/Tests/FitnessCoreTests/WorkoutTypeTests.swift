import Foundation
import Testing
@testable import FitnessCore

@Suite("WorkoutType")
struct WorkoutTypeTests {
    @Test func workoutTypeRoundTripsThroughCodableWorkout() throws {
        let workout = Workout(name: "Leg Day", type: .leg)

        let data = try JSONEncoder().encode(workout)
        let decoded = try JSONDecoder().decode(Workout.self, from: data)

        #expect(decoded.type == .leg)
    }

    @Test func legacyWorkoutWithoutTypeFallsBackToIndividual() throws {
        let workout = Workout(name: "Legacy")
        let encoded = try JSONEncoder().encode(workout)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "type")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Workout.self, from: legacyData)

        #expect(decoded.type == .individual)
    }

    @Test func unknownWorkoutTypeFallsBackToIndividual() throws {
        let workout = Workout(name: "Future")
        let encoded = try JSONEncoder().encode(workout)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["type"] = "hybrid"

        let futureData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Workout.self, from: futureData)

        #expect(decoded.type == .individual)
    }

    @Test func pickerOrderMatchesProductSpecification() {
        #expect(WorkoutType.allCases == [.pull, .push, .leg, .individual, .full])
    }
}
