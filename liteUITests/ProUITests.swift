import XCTest

@MainActor
final class ProUITests: XCTestCase {
    func testUnavailablePlansRemainDismissibleWithAccessibilityText() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["home.settings"].tap()
        app.buttons["settings.pro"].tap()
        let close = app.buttons["pro.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pro.purchase"].exists, "No purchase should be offered without a StoreKit product")
        let restore = app.buttons["pro.restore"]
        for _ in 0..<8 where !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(restore.isHittable)
        XCTAssertTrue(close.isHittable, "Close stays reachable while large text scrolls")
        close.tap()
        XCTAssertTrue(app.buttons["settings.pro"].waitForExistence(timeout: 3))
    }

    func testThirdProfileIsFreeAndFourthShowsDismissiblePaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-locked-fixture"]
        app.launch()
        app.buttons["home.settings"].tap()
        app.buttons["settings.apps"].tap()
        app.buttons["settings.app.Public Fixture"].tap()
        let duplicate = app.buttons["Create Another Account"]
        for _ in 0..<4 where !duplicate.isHittable { app.swipeUp() }
        XCTAssertTrue(duplicate.isHittable)
        duplicate.tap()
        XCTAssertFalse(app.buttons["pro.close"].exists)
        duplicate.tap()
        XCTAssertTrue(app.buttons["pro.close"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Your free plan includes 3 added profiles, plus the included starter apps. Add unlimited profiles with Lite Pro."].exists)
        XCTAssertTrue(app.buttons["pro.restore"].exists)
        app.buttons["pro.close"].tap()
        XCTAssertTrue(duplicate.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["container.done"].exists)
    }

    func testOverLimitGroupsRemainEditableAndNewGroupIsGated() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-groups-fixture"]
        app.launch()
        app.tabBars.buttons["Groups"].tap()
        app.buttons["groups.menu.Work"].tap()
        app.buttons["Edit Group"].tap()
        app.buttons["groups.editor.save"].tap()
        XCTAssertTrue(app.buttons["groups.menu.Work"].waitForExistence(timeout: 3))
        app.buttons["groups.add"].tap()
        let name = app.textFields["groups.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap(); name.typeText("Another")
        app.buttons["groups.editor.app.LinkedIn"].tap()
        app.buttons["groups.editor.app.Gmail"].tap()
        app.buttons["groups.editor.save"].tap()
        XCTAssertTrue(app.buttons["pro.close"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your free plan includes 1 group. Organize more groups with Lite Pro."].exists)
    }
}
