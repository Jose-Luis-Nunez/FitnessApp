import SwiftUI
import Testing
import FitnessCore
import FitnessUI
@testable import FitnessWorkouts

@Suite("WorkoutTileArtwork", .tags(.fast))
struct WorkoutTileArtworkTests {
    @Test func usesGenericWorkoutArtwork() {
        #expect(WorkoutTileArtwork.assetName == "workoutDefaultIcon")
    }

    @Test func artworkAlignmentMatchesWorkoutTypeSpecification() {
        #expect(WorkoutType.pull.iconAlignment == .top)
        #expect(WorkoutType.push.iconAlignment == .top)
        #expect(WorkoutType.leg.iconAlignment == .bottom)
        #expect(WorkoutType.individual.iconAlignment == .top)
        #expect(WorkoutType.full.iconAlignment == .top)
    }
}
