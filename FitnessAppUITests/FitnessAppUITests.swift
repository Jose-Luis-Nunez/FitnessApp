import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        verifyExistsByPredicate(HomeSelectors.categoryTilePredicate)
        let tile = app.descendants(matching: .any)
            .matching(HomeSelectors.categoryTilePredicate)
            .firstMatch
        tile.tap()

        tapOn(MuscleCategorySelectors.startExercise, timeout: 10)

        tapOnIfExists(TrainingSelectors.startButton)

        for setIndex in 1...3 {
            tapOn(TrainingSelectors.doneButton)

            if setIndex < 3 {
                tapOnIfExists(TrainingSelectors.startButton, timeout: 2)
            }
        }

        tapOn(TrainingSelectors.finishButton)
        verifyNotExists(TrainingSelectors.finishButton)
    }
}
