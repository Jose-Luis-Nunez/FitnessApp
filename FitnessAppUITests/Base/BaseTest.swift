import XCTest

class BaseTest: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("--uitesting")
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func startAccessibilityAudit() throws {
        try app.performAccessibilityAudit(for: [.hitRegion, .trait, .textClipped])
    }
}
