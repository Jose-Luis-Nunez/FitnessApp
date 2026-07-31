import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        try launch(training: .defaultArmsExercise)

        for setIndex in 1...3 {
            tapOn(TrainingIDs.doneButton)
            waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
        }

        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.finishButton)
    }

    @MainActor
    func testBilateralTrainingCompletesLeftAndRightForEveryLogicalSet() throws {
        try launch(training: .bilateralTorsoExercise)

        verifyExists(TrainingIDs.sideHeader("left"))
        verifyExists(TrainingIDs.sideHeader("right"))

        for logicalSet in 0..<3 {
            for side in ["left", "right"] {
                tapOn(TrainingIDs.doneButton)
                waitForNonEmptyLabel(
                    TrainingIDs.repsField(logicalSet: logicalSet, side: side)
                )
                if logicalSet < 2 || side == "left" {
                    verifyNotExists(TrainingIDs.finishButton)
                }
            }
        }

        verifyExists(TrainingIDs.finishButton)
        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.finishButton)

        tapOnWithPrefix(ExerciseCardIDs.completedCardPrefix)
        tapOnWithPrefix(ExerciseCardIDs.analyticsPrefix)

        verifyExists(AnalyticsIDs.screen)
        for logicalSet in 0..<3 {
            verifyExists(
                AnalyticsIDs.bilateralResult(logicalSet: logicalSet, side: "left")
            )
            verifyExists(
                AnalyticsIDs.bilateralResult(logicalSet: logicalSet, side: "right")
            )
        }
    }
}
