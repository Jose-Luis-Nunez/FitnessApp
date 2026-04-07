import XCTest

extension XCUIElement {
    func tapSafely(timeout: TimeInterval = 5) {
        guard self.waitForExistence(timeout: timeout) else {
            XCTFail("Element not found in \(timeout)s: \(self)")
            return
        }
        self.firstMatch.tap()
    }

    func typeSafely(_ text: String, timeout: TimeInterval = 10) {
        guard self.waitForExistence(timeout: timeout) else {
            XCTFail("Element not found for typing: \(self)")
            return
        }
        self.firstMatch.tap()
        self.firstMatch.typeText(text)
    }
}

extension XCUIApplication {
    func element(withIdentifier id: String, type: XCUIElement.ElementType = .any) -> XCUIElement {
        descendants(matching: type).matching(identifier: id).firstMatch
    }

    func element(withLabel label: String, type: XCUIElement.ElementType = .any) -> XCUIElement {
        descendants(matching: type)[label].firstMatch
    }
}
