import XCTest

final class ScheduleUITests: BaseTest {

    @MainActor
    func testScheduleScreenLoads() throws {
        let config = UITestLaunchConfig.schedule()
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()
    }
}
