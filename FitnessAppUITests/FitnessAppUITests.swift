import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        app.launch()

        tapOn(HomeSelectors.categoryTile)

        tapOn(MuscleCategorySelectors.startExercise, timeout: TestDefaults.longTimeout)

        for setIndex in 1...3 {
            tapOn(TrainingSelectors.doneButton)
            waitForNonEmptyLabel(TrainingSelectors.repsField(set: setIndex - 1))
        }

        tapOn(TrainingSelectors.finishButton)
        verifyNotExists(TrainingSelectors.finishButton)
    }
}
