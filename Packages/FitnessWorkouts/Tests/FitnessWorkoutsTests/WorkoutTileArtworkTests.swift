import SwiftUI
import Testing
import FitnessCore
@testable import FitnessWorkouts

@Suite("WorkoutTileArtwork", .tags(.fast))
struct WorkoutTileArtworkTests {
    @Test func usesGenericWorkoutArtwork() {
        #expect(WorkoutTileArtwork.assetName == "workoutDefaultIcon")
    }

    @Test func heroArtworkUsesFixedTopCropForEveryWorkoutType() {
        for type in WorkoutType.allCases {
            #expect(WorkoutTileArtwork.heroCropAlignment(for: type) == .top)
        }
    }
}
