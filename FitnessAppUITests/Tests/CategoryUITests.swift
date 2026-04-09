import XCTest

final class CategoryUITests: BaseTest {

    @MainActor
    func testCategoryScreenShowsExercises() throws {
        let config = UITestLaunchConfig.category("arms")
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()

        verifyExists(MuscleCategoryIDs.startExercise)
    }
}
