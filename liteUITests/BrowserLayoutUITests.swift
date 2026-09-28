import XCTest

@MainActor
final class BrowserLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-web-fixture", "--uitesting-locked-fixture", "--uitesting-immersive-fixture"]
        app.launch()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Journal"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 3))
    }

    func testScrollingCoordinatesWebsiteTabsAndToolbarPosition() {
        let web = app.webViews.firstMatch
        let expandedHeight = web.frame.height
        let domainFrame = app.buttons["browser.websiteInfo"].frame
        let footerFrame = app.webViews.buttons["Change page color"].frame
        let screenBottom = app.frame.maxY
        XCTAssertEqual(screenBottom - domainFrame.midY, 56, accuracy: 2, "Expanded controls match the reference's bottom position")
        XCTAssertEqual(domainFrame.midX, web.frame.midX, accuracy: 1)
        XCTAssertTrue(app.buttons["browser.reload"].exists)
        XCTAssertLessThan(web.frame.minY, 65, "The website should start below the status area, without a native top toolbar")
        XCTAssertFalse(app.buttons["browser.home"].exists, "Start Page is in More")
        assertFooterAbove(app.buttons["browser.more"])
        attach("Immersive expanded dark")

        web.swipeUp()
        let pill = app.buttons["browser.expand"]
        XCTAssertTrue(pill.waitForExistence(timeout: 3))
        XCTAssertTrue(pill.isHittable)
        XCTAssertEqual(web.frame.height, expandedHeight, accuracy: 1, "Toolbar animation must not resize the website")
        XCTAssertEqual(pill.frame.midX, domainFrame.midX, accuracy: 1)
        XCTAssertEqual(pill.frame.midX, web.frame.midX, accuracy: 1, "The pill must stay centered on the screen")
        XCTAssertEqual(pill.frame.midY - domainFrame.midY, 28, accuracy: 1, "Collapse settles lower like the reference")
        XCTAssertEqual(screenBottom - pill.frame.midY, 28, accuracy: 2, "The compact pill sits close to the bottom edge")
        XCTAssertEqual(app.webViews.buttons["Change page color"].frame.midY - footerFrame.midY, 40, accuracy: 2,
                       "The website's fixed tab bar must move down as browser controls collapse")
        XCTAssertGreaterThanOrEqual(pill.frame.height, 44, "Compact artwork must retain an accessible touch target")
        XCTAssertFalse(app.buttons["browser.close"].exists)
        XCTAssertFalse(app.buttons["browser.back"].exists)
        XCTAssertFalse(app.buttons["browser.more"].exists)
        XCTAssertFalse(app.buttons["browser.reload"].exists)
        let siteHeader = app.webViews.staticTexts["Journal"]
        XCTAssertTrue(siteHeader.isHittable)
        XCTAssertGreaterThanOrEqual(siteHeader.frame.minY, web.frame.minY)
        XCTAssertLessThan(siteHeader.frame.maxY, web.frame.minY + 64)
        assertFooterAbove(pill)
        attach("Immersive collapsed dark")

        pill.tap()
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.webViews.buttons["Change page color"].frame.midY, footerFrame.midY, accuracy: 2,
                       "Expanding restores the website tab bar above the toolbar")
        web.swipeUp()
        XCTAssertTrue(pill.waitForExistence(timeout: 3))
        web.swipeDown()
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 3))
        app.buttons["browser.close"].tap()
        XCTAssertTrue(app.buttons["home.app.Public Fixture"].waitForExistence(timeout: 3))
    }

    func testPageColorChangesWithoutChangingWebsitePreferenceAndKeyboardExpandsControls() {
        let preference = app.webViews.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Website preference:")).firstMatch
        XCTAssertTrue(preference.exists)
        let initialPreference = preference.label
        app.webViews.buttons["Change page color"].tap()
        XCTAssertEqual(preference.label, initialPreference)
        attach("Immersive expanded light")

        app.webViews.firstMatch.swipeUp()
        XCTAssertTrue(app.buttons["browser.expand"].waitForExistence(timeout: 3))
        let note = app.webViews.textFields["Write a note"]
        XCTAssertTrue(note.isHittable)
        note.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["browser.expand"].exists)
        note.typeText("Still reachable")
        XCTAssertEqual(note.value as? String, "Still reachable")
        XCTAssertLessThanOrEqual(app.buttons["browser.more"].frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        attach("Immersive keyboard")
    }

    func testFloatingControlsOverAnArticleWithoutAFixedFooter() {
        app.terminate()
        app.launchArguments += ["--uitesting-underlap-fixture"]
        app.launch()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Journal"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 3))
        let web = app.webViews.firstMatch
        XCTAssertGreaterThan(web.frame.maxY, app.buttons["browser.more"].frame.maxY,
                             "The webpage must extend underneath the floating toolbar")
        XCTAssertFalse(app.webViews.buttons["Change page color"].exists)
        attach("Floating glass over article")
        web.swipeUp()
        XCTAssertTrue(app.buttons["browser.expand"].waitForExistence(timeout: 3))
        attach("Compact glass over article")
        app.buttons["browser.expand"].tap()
        XCTAssertTrue(app.buttons["browser.reload"].waitForExistence(timeout: 3))
    }

    private func assertFooterAbove(_ nativeControl: XCUIElement) {
        let footerButton = app.webViews.buttons["Change page color"]
        XCTAssertTrue(footerButton.isHittable)
        XCTAssertLessThanOrEqual(footerButton.frame.maxY, nativeControl.frame.minY + 1)
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
