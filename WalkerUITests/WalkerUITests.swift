import XCTest

final class WalkerUITests: XCTestCase {
    func testFullGameLoop() {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["START RUN"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        XCTAssertTrue(app.staticTexts["HEAD START"].waitForExistence(timeout: 5))

        let horde = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'HORDE'")
        ).firstMatch
        XCTAssertTrue(horde.waitForExistence(timeout: 100))

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()

        app.buttons["END"].tap()
        XCTAssertTrue(app.staticTexts["YOU MADE IT OUT"].waitForExistence(timeout: 5))

        app.buttons["Run again"].tap()
        XCTAssertTrue(app.staticTexts["HEAD START"].waitForExistence(timeout: 5))

        app.buttons["pauseToggle"].tap()
        XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 5))
        app.buttons["Resume"].tap()
        app.buttons["END"].tap()
        XCTAssertTrue(app.staticTexts["YOU MADE IT OUT"].waitForExistence(timeout: 5))

        app.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["START RUN"].waitForExistence(timeout: 5))

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'Survived'")
            ).firstMatch.waitForExistence(timeout: 5)
        )
    }

    func testSkullSymbolRenders() {
        let app = XCUIApplication()
        app.launch()
        let skull = app.images["skull.fill"]
        let exists = skull.waitForExistence(timeout: 5)
        print("SKULL_SYMBOL_EXISTS: \(exists)")
        XCTAssertTrue(exists, "skull.fill SF Symbol did not render on Home screen")
    }
}


