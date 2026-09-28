import XCTest

@MainActor
final class BrowserProtectionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-web-fixture", "--uitesting-locked-fixture"]
        app.launch()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 30))
    }

    func testPopupWaitsThenClosesBackToOriginalPage() {
        tapWebLink("Open window")
        XCTAssertTrue(app.buttons["browser.openWindow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].exists)
        XCTAssertFalse(app.buttons["browser.closeWindow"].exists)
        attach("Popup waits for permission")
        app.buttons["browser.dismissWindow"].tap()
        XCTAssertFalse(app.buttons["browser.openWindow"].exists)
        XCTAssertTrue(app.webViews.textFields["Your note"].exists)
        tapWebLink("Open window")
        app.buttons["browser.openWindow"].tap()
        XCTAssertTrue(app.buttons["browser.closeWindow"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["browser.closeWindow"].label, "Close popup and return")
        XCTAssertTrue(app.buttons["browser.back"].isEnabled)
        assertStartPageInMenu()
        attach("Popup has a clear return control")
        app.buttons["browser.closeWindow"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.webViews.textFields["Your note"].value as? String, "Keep my place")
    }

    func testAdsAndAdRedirectsDoNotTakeOverAndUsefulContentStaysVisible() {
        XCTAssertFalse(app.webViews.staticTexts["Fixture advertisement"].exists)
        let useful = app.webViews.staticTexts["Useful website content"]
        XCTAssertTrue(useful.exists)
        tapWebLink("Open ad window")
        XCTAssertTrue(app.staticTexts["browser.protectionNotice"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["browser.openWindow"].exists)
        XCTAssertFalse(app.buttons["browser.closeWindow"].exists)
        let redirect = app.webViews.buttons["Ad redirect"]
        for _ in 0..<4 where !redirect.isHittable { app.webViews.firstMatch.swipeUp() }
        redirect.tap()
        XCTAssertTrue(app.staticTexts["browser.protectionNotice"].exists)
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].exists)
        assertStartPageInMenu()
        attach("Ad blocked without leaving the page")
    }

    func testWrittenPopupAndNestedPopupReturnInOrder() {
        let open = app.webViews.buttons["Open written window"]
        for _ in 0..<4 where !open.isHittable { app.webViews.firstMatch.swipeUp() }
        open.tap()
        XCTAssertTrue(app.buttons["browser.openWindow"].waitForExistence(timeout: 3))
        app.buttons["browser.openWindow"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Website window"].waitForExistence(timeout: 5))
        attach("Written window before nested tap")
        let nested = app.webViews.links["Nested window"]
        XCTAssertTrue(nested.exists)
        // document.write about:blank windows can report no AX hit point even
        // with a visible link. Send a real touch at its measured on-screen frame
        // and require the resulting window request to prove it was interactive.
        nested.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["browser.openWindow"].waitForExistence(timeout: 3))
        app.buttons["browser.openWindow"].tap()
        app.buttons["browser.closeWindow"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Website window"].waitForExistence(timeout: 3))
        app.buttons["browser.closeWindow"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 3))
    }

    func testWindowPromptAtAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.links["Open window"].waitForExistence(timeout: 30))
        tapWebLink("Open window")
        XCTAssertTrue(app.buttons["browser.openWindow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["browser.openWindow"].isHittable)
        XCTAssertTrue(app.buttons["browser.dismissWindow"].isHittable)
        assertStartPageInMenu()
        attach("Accessible popup controls")
    }

    private func assertStartPageInMenu() {
        app.buttons["browser.more"].tap()
        let home = app.buttons["browser.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 3))
        XCTAssertTrue(home.isEnabled)
        XCTAssertTrue(home.isHittable)
        // Dismiss the menu without navigating away from the page under test.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
    }

    private func tapWebLink(_ title: String) {
        let link = app.webViews.links[title]
        for _ in 0..<4 where !link.isHittable { app.webViews.firstMatch.swipeUp() }
        link.tap()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
