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
}
