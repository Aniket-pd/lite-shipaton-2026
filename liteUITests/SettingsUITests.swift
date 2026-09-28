import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-locked-fixture"]
        app.launch()
        app.buttons["home.settings"].tap()
    }

    func testAppSettingsSearchAndLockedAccess() {
        attach("Settings overview")
        app.buttons["settings.apps"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Locked")
        XCTAssertFalse(app.buttons["settings.app.Public Fixture"].exists)
        app.buttons["settings.app.Locked Fixture"].tap()
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["container.data"].exists)
        XCTAssertFalse(app.buttons["container.preferences"].exists)
    }

    func testPrivacySummaryUpdatesAndPermissionsHaveOneHome() {
        app.buttons["settings.privacy"].tap()
        XCTAssertTrue(app.staticTexts["On for 2 of 2 apps"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 of 2 apps locked"].exists)
        app.buttons["privacy.blocking"].tap()
        app.buttons["settings.app.Public Fixture"].tap()
        let toggle = app.switches["preferences.protection"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        app.buttons["container.done"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["On for 1 of 2 apps"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["settings.apps"].tap()
        app.buttons["settings.app.Public Fixture"].tap()
        app.buttons["container.preferences"].tap()
        XCTAssertTrue(app.buttons["preferences.layout"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["preferences.protection"].exists)
        XCTAssertFalse(app.buttons["preferences.camera"].exists)
    }

    func testWidgetSelectionAndLibraryFavoritesStayIndependent() {
        app.buttons["settings.widgets"].tap()
        let toggle = app.switches["widgets.app.Public Fixture"]
        for _ in 0..<3 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        attach("Widget selection")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["settings.manageLibrary"].tap()
        let favorite = app.buttons["organize.favorite.Public Fixture"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        XCTAssertEqual(favorite.label, "Favorite Public Fixture")
        favorite.tap()
        XCTAssertEqual(favorite.label, "Remove Public Fixture from favorites")
        app.navigationBars["Organize Library"].buttons["Settings"].firstMatch.tap()
        app.buttons["settings.widgets"].tap()
        XCTAssertEqual(app.switches["widgets.app.Public Fixture"].value as? String, "1")
    }

    func testAppearanceSurvivesRelaunch() {
        app.buttons["settings.appearance"].tap()
        app.buttons["appearance.dark"].tap()
        attach("Appearance dark")
        app.terminate()
        app.launch()
        app.buttons["home.settings"].tap()
        app.buttons["settings.appearance"].tap()
        XCTAssertTrue(app.buttons["appearance.dark"].isSelected)
        app.buttons["appearance.light"].tap()
        XCTAssertTrue(app.buttons["appearance.light"].isSelected)
        app.buttons["appearance.system"].tap()
    }

    func testLibraryAppNamesCanBeHidden() {
        app.buttons["settings.appearance"].tap()
        let toggle = app.switches["appearance.appNames"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String != "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")

        app.buttons["settings.done"].tap()
        XCTAssertFalse(app.staticTexts["Example"].exists)
        XCTAssertTrue(app.buttons["home.app.Example"].exists)

        app.buttons["home.settings"].tap()
        app.buttons["settings.appearance"].tap()
        let restoredToggle = app.switches["appearance.appNames"]
        XCTAssertTrue(restoredToggle.waitForExistence(timeout: 5))
        restoredToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    func testEmptyLibraryAndLargeTextHelp() {
        app.terminate()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["home.settings"].tap()
        let apps = app.buttons["settings.apps"]
        for _ in 0..<4 where !apps.isHittable { app.swipeUp() }
        apps.tap()
        XCTAssertTrue(app.staticTexts["No Lite Apps Yet"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let help = app.buttons["settings.help"]
        for _ in 0..<5 where !help.isHittable { app.swipeUp() }
        XCTAssertTrue(help.isHittable)
        attach("Settings large text")
        help.tap()
        XCTAssertTrue(app.navigationBars["Help & Troubleshooting"].waitForExistence(timeout: 5))
    }

    func testAboutUsesSettingsNavigationStack() {
        app.buttons["settings.about"].tap()
        XCTAssertTrue(app.navigationBars["About Lite"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons["Settings"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["about.version"].exists)
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
