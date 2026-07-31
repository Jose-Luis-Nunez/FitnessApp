import XCTest

class BaseTest: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("--uitesting")
    }

    override func tearDownWithError() throws {
        if let failureCount = testRun?.failureCount, failureCount > 0 {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.terminate()
    }

    // MARK: - Screen Launch Helpers

    @MainActor
    func launchCategorySelection() throws {
        let config = UITestLaunchConfig.home()
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()
    }

    @MainActor
    func launch(
        training fixture: TestExerciseFixture,
        additional: [TestExerciseFixture] = []
    ) throws {
        let config = UITestLaunchConfig.training(fixture, additional: additional)
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()
    }

    @MainActor
    func launch(category name: String) throws {
        let config = UITestLaunchConfig.category(name)
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()
    }

    @MainActor
    func launch(
        exerciseList fixture: TestExerciseFixture,
        additional: [TestExerciseFixture] = []
    ) throws {
        let config = UITestLaunchConfig.exerciseList(fixture, additional: additional)
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()
    }

    @MainActor
    func launch(
        exerciseCategory fixture: TestExerciseFixture,
        additional: [TestExerciseFixture] = [],
        seedAnalyticsHistory: Bool = false
    ) throws {
        let config = UITestLaunchConfig.exerciseCategory(
            fixture,
            additional: additional,
            seedAnalyticsHistory: seedAnalyticsHistory
        )
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()
    }

    @MainActor
    func launchSchedule() throws {
        let config = UITestLaunchConfig.schedule()
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()
    }

    @MainActor
    func launchHome() {
        app.launch()
    }
}
