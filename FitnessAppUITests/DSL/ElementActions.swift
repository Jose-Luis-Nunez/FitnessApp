import XCTest

// MARK: - Defaults

enum TestDefaults {
    static let timeout: TimeInterval = 5.0
    static let shortTimeout: TimeInterval = 2.0
    static let longTimeout: TimeInterval = 10.0
}

// MARK: - DSL

extension BaseTest {

    // MARK: - Tap

    @MainActor
    func tapOn(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .button,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        guard let element = findElement(in: app, identifier: identifier, elementType: elementType, timeout: timeout) else {
            XCTFail("tapOn: '\(identifier)' not found within \(timeout)s")
            return
        }
        element.tap()
    }

    @MainActor
    func tapOn(
        label: String,
        elementType: XCUIElement.ElementType = .button,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        guard let element = findElement(in: app, label: label, elementType: elementType, timeout: timeout) else {
            XCTFail("tapOn: label '\(label)' not found within \(timeout)s")
            return
        }
        element.tap()
    }

    @MainActor
    func tapOnIfExists(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .button,
        timeout: TimeInterval = TestDefaults.shortTimeout
    ) {
        if let element = findElement(in: app, identifier: identifier, elementType: elementType, timeout: timeout) {
            element.tap()
        }
    }

    // MARK: - Fill

    @MainActor
    func fill(_ selector: String, with text: String, timeout: TimeInterval = TestDefaults.timeout) {
        let textField = app.textFields[selector]
        let secureField = app.secureTextFields[selector]

        let predicate = NSPredicate(format: "exists == YES")
        let textExpectation = XCTNSPredicateExpectation(predicate: predicate, object: textField)
        let secureExpectation = XCTNSPredicateExpectation(predicate: predicate, object: secureField)

        _ = XCTWaiter().wait(for: [textExpectation, secureExpectation], timeout: timeout, enforceOrder: false)

        let field: XCUIElement
        if textField.exists {
            field = textField
        } else if secureField.exists {
            field = secureField
        } else {
            XCTFail("TextField: '\(selector)' not found within \(timeout)s")
            return
        }

        field.tap()
        field.typeText(text)
    }

    @MainActor
    func fillPickerInput(_ selector: String, with text: String, timeout: TimeInterval = TestDefaults.timeout) {
        let button = app.buttons[selector]
        guard button.waitForExistence(timeout: timeout) else {
            XCTFail("fillPickerInput: '\(selector)' not found within \(timeout)s")
            return
        }

        button.tap()
        button.typeText(text)
    }

    // MARK: - Verify

    @MainActor
    func verifyExists(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        let element = app
            .descendants(matching: elementType)
            .matching(identifier: identifier)
            .firstMatch
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected '\(identifier)' to exist"
        )
    }

    @MainActor
    func verifyExists(
        label: String,
        elementType: XCUIElement.ElementType = .button,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        XCTAssertNotNil(
            findElement(
                in: app,
                label: label,
                elementType: elementType,
                timeout: timeout
            ),
            "Expected element with label '\(label)' to exist"
        )
    }

    @MainActor
    func verifyIsDisabled(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .button,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        guard let element = findElement(
            in: app,
            identifier: identifier,
            elementType: elementType,
            timeout: timeout
        ) else {
            XCTFail("verifyIsDisabled: '\(identifier)' not found within \(timeout)s")
            return
        }
        XCTAssertFalse(element.isEnabled, "Expected '\(identifier)' to be disabled")
    }

    @MainActor
    func verifyIsEnabled(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .button,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        guard let element = findElement(
            in: app,
            identifier: identifier,
            elementType: elementType,
            timeout: timeout
        ) else {
            XCTFail("verifyIsEnabled: '\(identifier)' not found within \(timeout)s")
            return
        }
        XCTAssertTrue(element.isEnabled, "Expected '\(identifier)' to be enabled")
    }

    @MainActor
    func verifyNotExists(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = TestDefaults.shortTimeout
    ) {
        let element = app
            .descendants(matching: elementType)
            .matching(identifier: identifier)
            .firstMatch
        let predicate = NSPredicate(format: "exists == NO")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Expected '\(identifier)' to NOT exist within \(timeout)s")
    }

    @MainActor
    func verifyLabel(
        _ identifier: String,
        equals expected: String,
        elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        let element = app
            .descendants(matching: elementType)
            .matching(identifier: identifier)
            .firstMatch
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Expected '\(identifier)' label to equal '\(expected)', got '\(element.label)'")
    }

    @MainActor
    func verifyExistsWithPrefix(
        _ prefix: String,
        elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        let element = app
            .descendants(matching: elementType)
            .matching(predicate)
            .firstMatch
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected element with identifier starting with '\(prefix)' to exist"
        )
    }

    @MainActor
    func verifyNotExistsWithPrefix(
        _ prefix: String,
        elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = TestDefaults.shortTimeout
    ) {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        let element = app
            .descendants(matching: elementType)
            .matching(predicate)
            .firstMatch
        let notExists = NSPredicate(format: "exists == NO")
        let expectation = XCTNSPredicateExpectation(predicate: notExists, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Expected no element with identifier starting with '\(prefix)' to exist within \(timeout)s")
    }

    @MainActor
    func frameOf(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = TestDefaults.timeout
    ) -> CGRect {
        guard let element = findElement(
            in: app,
            identifier: identifier,
            elementType: elementType,
            timeout: timeout
        ) else {
            XCTFail("frameOf: '\(identifier)' not found within \(timeout)s")
            return .zero
        }
        return element.frame
    }

    @MainActor
    func framesOfElements(
        withPrefix prefix: String,
        limit: Int,
        elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = TestDefaults.timeout
    ) -> [CGRect] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        let query = app.descendants(matching: elementType).matching(predicate)

        guard query.firstMatch.waitForExistence(timeout: timeout) else {
            XCTFail("framesOfElements: no element starting with '\(prefix)' found within \(timeout)s")
            return []
        }

        let frames = sortFramesInReadingOrder(query.allElementsBoundByIndex.map(\.frame))
        guard frames.count >= limit else {
            XCTFail("framesOfElements: expected at least \(limit) elements starting with '\(prefix)', found \(frames.count)")
            return frames
        }
        return Array(frames.prefix(limit))
    }

    @MainActor
    func attachDiagnosticScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Wait

    @MainActor
    func waitForNonEmptyLabel(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .button,
        timeout: TimeInterval = TestDefaults.timeout
    ) {
        let element = app.descendants(matching: elementType)
            .matching(identifier: identifier).firstMatch
        let predicate = NSPredicate(format: "label != ''")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Expected '\(identifier)' to have a non-empty label within \(timeout)s")
    }

    // MARK: - Scroll

    @MainActor
    func swipeUpUntilVisible(
        _ identifier: String,
        elementType: XCUIElement.ElementType = .any,
        maxSwipes: Int = 5
    ) {
        let element = app.descendants(matching: elementType)
            .matching(identifier: identifier).firstMatch

        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }

        XCTAssertTrue(element.exists && element.isHittable,
                      "'\(identifier)' not visible after \(maxSwipes) swipes")
    }

    // MARK: - Find (internal)

    @MainActor
    func findElement(
        in container: XCUIElement,
        identifier: String? = nil,
        label: String? = nil,
        elementType: XCUIElement.ElementType,
        timeout: TimeInterval = TestDefaults.timeout
    ) -> XCUIElement? {
        let query = container.descendants(matching: elementType)
        let element: XCUIElement

        if let identifier {
            element = query.matching(identifier: identifier).firstMatch
        } else if let label {
            element = query[label].firstMatch
        } else {
            return nil
        }

        return element.waitForExistence(timeout: timeout) ? element : nil
    }
}

@MainActor
func sortFramesInReadingOrder(_ frames: [CGRect]) -> [CGRect] {
    frames.sorted { lhs, rhs in
        if abs(lhs.minY - rhs.minY) > 0.5 {
            return lhs.minY < rhs.minY
        }
        return lhs.minX < rhs.minX
    }
}
