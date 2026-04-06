//
//  FitnessAppUITests.swift
//  FitnessAppUITests
//
//  Created by Jose Nunez on 13.04.25.
//

import XCTest

final class FitnessAppUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Full Training Flow

    @MainActor
    func testFullTrainingFlow() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // 1. Tap the first category tile on the home screen.
        //    The app auto-navigates to home when a default workout exists.
        let firstCategoryTile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'id_category_tile_'")
        ).firstMatch
        XCTAssertTrue(firstCategoryTile.waitForExistence(timeout: 5), "Category tile should be visible on home screen")
        firstCategoryTile.tap()

        // 2. Tap the play button on the first exercise card.
        let playButton = app.buttons["id_button_start_exercise"].firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "Play button should appear on exercise card")
        playButton.tap()

        // 3. Now in TrainingView. The action bar shows a "Start" button first.
        //    After tapping Start, "Done" becomes available per set.
        let startButton = app.buttons["id_button_start"].firstMatch
        if startButton.waitForExistence(timeout: 3) {
            startButton.tap()
        }

        // 4. Tap "Done" 3 times to complete 3 sets.
        for i in 1...3 {
            let doneButton = app.buttons["id_button_done"].firstMatch
            XCTAssertTrue(
                doneButton.waitForExistence(timeout: 5),
                "Done button should appear for set \(i)"
            )
            doneButton.tap()

            // After tapping Done, "Start" may reappear for the next set.
            let nextStart = app.buttons["id_button_start"].firstMatch
            if nextStart.waitForExistence(timeout: 2) {
                nextStart.tap()
            }
        }

        // 5. Tap "Beenden" to finish the training.
        let finishButton = app.buttons["id_button_finish"].firstMatch
        XCTAssertTrue(
            finishButton.waitForExistence(timeout: 5),
            "Beenden button should appear after completing all sets"
        )
        finishButton.tap()

        // 6. Verify we navigated back — the training view should be gone.
        //    The finish button disappears and the app returns to the category view.
        let trainingFinished = finishButton.waitForNonExistence(timeout: 5)
        XCTAssertTrue(trainingFinished, "Should leave the training screen after tapping Beenden")
    }
}
