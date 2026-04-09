import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        
        let config = UITestLaunchConfig.training(.defaultArmsExercise)
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()

        for setIndex in 1...3 {
            tapOn(TrainingIDs.doneButton)
            waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
        }

        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.finishButton)
    }
}
