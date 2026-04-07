import XCTest

// MARK: - Tap

@MainActor
func tapOn(
    _ identifier: String,
    elementType: XCUIElement.ElementType = .button,
    timeout: TimeInterval = 5.0
) {
    let app = XCUIApplication()

    retryAction {
        if let element = findElement(in: app, identifier: identifier, elementType: elementType, timeout: timeout) {
            element.tap()
            return true
        }
        return false
    }
}

@MainActor
func tapOn(
    label: String,
    elementType: XCUIElement.ElementType = .button,
    timeout: TimeInterval = 5.0
) {
    let app = XCUIApplication()

    retryAction {
        if let element = findElement(in: app, label: label, elementType: elementType, timeout: timeout) {
            element.tap()
            return true
        }
        return false
    }
}

@MainActor
func tapOnIfExists(
    _ identifier: String,
    elementType: XCUIElement.ElementType = .button,
    timeout: TimeInterval = 3.0
) {
    let app = XCUIApplication()
    if let element = findElement(in: app, identifier: identifier, elementType: elementType, timeout: timeout) {
        element.tap()
    }
}

// MARK: - Fill

@MainActor
func fill(_ selector: String, with text: String, timeout: TimeInterval = 5.0) {
    let app = XCUIApplication()
    let field: XCUIElement

    if app.textFields[selector].waitForExistence(timeout: timeout) {
        field = app.textFields[selector]
    } else if app.secureTextFields[selector].waitForExistence(timeout: timeout) {
        field = app.secureTextFields[selector]
    } else {
        XCTFail("TextField: '\(selector)' not found.")
        return
    }

    field.tap()
    field.typeText(text)
}

@MainActor
func fillForButtonElement(_ selector: String, with text: String, timeout: TimeInterval = 5.0) {
    let app = XCUIApplication()

    if app.buttons[selector].waitForExistence(timeout: timeout) {
        let field = app.buttons[selector]
        field.tap()
        field.typeText(text)
    } else {
        XCTFail("Button element: '\(selector)' not found.")
    }
}

// MARK: - Verify

@MainActor
func verifyExists(
    _ identifier: String,
    elementType: XCUIElement.ElementType = .any,
    timeout: TimeInterval = 5.0
) {
    let element = XCUIApplication()
        .descendants(matching: elementType)
        .matching(identifier: identifier)
        .firstMatch
    XCTAssertTrue(
        element.waitForExistence(timeout: timeout),
        "Expected '\(identifier)' to exist"
    )
}

@MainActor
func verifyNotExists(
    _ identifier: String,
    elementType: XCUIElement.ElementType = .any,
    timeout: TimeInterval = 2.0
) {
    let element = XCUIApplication()
        .descendants(matching: elementType)
        .matching(identifier: identifier)
        .firstMatch
    XCTAssertFalse(
        element.waitForExistence(timeout: timeout),
        "Expected '\(identifier)' to NOT exist"
    )
}

@MainActor
func verifyExistsByPredicate(
    _ predicate: NSPredicate,
    elementType: XCUIElement.ElementType = .any,
    timeout: TimeInterval = 5.0
) {
    let element = XCUIApplication()
        .descendants(matching: elementType)
        .matching(predicate)
        .firstMatch
    XCTAssertTrue(
        element.waitForExistence(timeout: timeout),
        "Expected element matching predicate to exist"
    )
}

@MainActor
func verifyNotExistsByPredicate(
    _ predicate: NSPredicate,
    elementType: XCUIElement.ElementType = .any,
    timeout: TimeInterval = 2.0
) {
    let element = XCUIApplication()
        .descendants(matching: elementType)
        .matching(predicate)
        .firstMatch
    XCTAssertFalse(
        element.waitForExistence(timeout: timeout),
        "Expected element matching predicate to NOT exist"
    )
}

// MARK: - Find & Retry (internal)

@MainActor
func findElement(
    in container: XCUIElement,
    identifier: String? = nil,
    label: String? = nil,
    elementType: XCUIElement.ElementType,
    timeout: TimeInterval = 5.0
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

@MainActor
func retryAction(
    _ action: @escaping () -> Bool,
    maxAttempts: Int = 5,
    retryInterval: TimeInterval = 0.3
) {
    for attempt in 1...maxAttempts {
        if action() { return }
        if attempt < maxAttempts {
            Thread.sleep(forTimeInterval: retryInterval)
        }
    }
    XCTFail("retryAction: Failed after \(maxAttempts) attempts")
}

@MainActor
func getButton(_ label: String, timeout: TimeInterval = 5.0) -> XCUIElement? {
    let element = XCUIApplication().buttons[label]
    return element.waitForExistence(timeout: timeout) ? element : nil
}
