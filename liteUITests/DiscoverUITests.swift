import XCTest

@MainActor
final class DiscoverUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-discover-fixture",
                               "-lite.atmosphericBackground", "NO"]
        app.launch()
        app.tabBars.buttons["Discover"].tap()
    }

    func testBrowseCategoriesAndTaskSearch() {
        XCTAssertTrue(app.staticTexts["All sites"].waitForExistence(timeout: 5))
        screenshot("Discover — browse")
        app.buttons["discover.category.AI"].tap()
        XCTAssertTrue(app.buttons["discover.service.chatgpt"].exists)
        XCTAssertFalse(app.buttons["discover.service.instagram"].exists)
        search("photo editor")
        XCTAssertTrue(app.buttons["discover.duckDuckGo"].exists)
        app.buttons["Search all categories"].tap()
        XCTAssertTrue(app.buttons["discover.service.photopea"].exists)
        XCTAssertTrue(app.buttons["discover.service.canva"].exists)
        screenshot("Discover — search results")
        app.buttons["discover.clearSearch"].tap()
        XCTAssertTrue(app.staticTexts["All sites"].exists)
    }

    func testDirectURLPreviewAndCancelDoesNotCreateAnApp() {
        search("example.com")
        XCTAssertTrue(app.staticTexts["Add this website"].exists)
        app.buttons["discover.service.https://example.com"].tap()
        XCTAssertTrue(app.buttons["discover.preview"].waitForExistence(timeout: 3))
        screenshot("Discover — website details")
        app.buttons["discover.preview"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Website preview"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["discover.web.add"].isEnabled)
        screenshot("Discover — preview")
        app.buttons["discover.dismiss"].tap()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["home.empty.add"].waitForExistence(timeout: 3))
    }

    func testWebSearchOpensAResultAndAddsIt() {
        search("a new tool")
        app.buttons["discover.duckDuckGo"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Search results"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["discover.web.add"].isEnabled)
        app.webViews.links["Example website"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Website preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["discover.web.add"].isEnabled)
        app.buttons["discover.web.add"].tap()
        let name = app.textFields["creation.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let suggestedName = name.value as? String ?? ""
        XCTAssertFalse(suggestedName.isEmpty)
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: suggestedName.count))
        name.typeText("Found website")
        app.buttons["creation.create"].tap()
        XCTAssertTrue(app.buttons["home.app.Found website"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Discover"].tap()
        app.buttons["discover.clearSearch"].tap()
        search("Found website")
        XCTAssertTrue(app.buttons["discover.saved.Found website"].exists)
    }

    func testInsecureURLShowsValidationInsteadOfSearching() {
        search("http://example.com")
        XCTAssertTrue(app.staticTexts["Check this address"].exists)
        XCTAssertFalse(app.buttons["discover.searchWeb"].exists)
        XCTAssertFalse(app.buttons["discover.web.add"].exists)
    }

    func testPreviewInformationPreservesPageAndAddsAfterDismissal() {
        app.terminate()
        app.launchArguments += ["-lite.appearance", "light"]
        app.launch()
        app.tabBars.buttons["Discover"].tap()
        search("a new tool\n")
        XCTAssertTrue(app.webViews.links["Example website"].waitForExistence(timeout: 60), "Allow cold content-blocker compilation")
        app.buttons["discover.web.sessionInfo"].tap()
        XCTAssertTrue(app.buttons["discover.web.info.add"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["discover.web.info.add"].isEnabled, "Search results cannot become a saved app")
        app.buttons["discover.web.info.close"].tap()
        app.webViews.links["Example website"].tap()
        let remember = app.webViews.buttons["Keep my place"]
        XCTAssertTrue(remember.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(remember.frame.maxY, app.buttons["discover.web.more"].frame.minY,
                                 "Fixed website controls stay above the native toolbar")
        screenshot("Preview — compact toolbar light")
        remember.tap()
        app.buttons["discover.web.information"].tap()
        XCTAssertTrue(app.buttons["discover.web.info.add"].waitForExistence(timeout: 3))
        screenshot("Preview — website information light")
        app.buttons["discover.web.info.close"].tap()
        XCTAssertTrue(app.webViews.buttons["Page state preserved"].waitForExistence(timeout: 3),
                      "Opening information must not close or reload the preview session")
        app.buttons["discover.web.sessionInfo"].tap()
        app.buttons["discover.web.info.add"].tap()
        XCTAssertTrue(app.textFields["creation.name"].waitForExistence(timeout: 5),
                      "Creation opens only after both preview sheets dismiss")
        XCTAssertEqual(app.textFields["creation.name"].value as? String, "Personal")
        app.buttons["creation.create"].tap()
        XCTAssertTrue(app.buttons["home.app.Personal"].waitForExistence(timeout: 5))
    }

    func testPreviewInformationAndActionsAtAccessibilitySize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-lite.appearance", "dark"]
        app.launch()
        app.tabBars.buttons["Discover"].tap()
        search("a new tool\n")
        XCTAssertTrue(app.webViews.links["Example website"].waitForExistence(timeout: 60), "Allow cold content-blocker compilation")
        app.webViews.links["Example website"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Website preview"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["discover.web.add"].isHittable)
        XCTAssertTrue(app.buttons["discover.dismiss"].isHittable)
        screenshot("Preview — accessibility dark")
        app.buttons["discover.web.sessionInfo"].tap()
        let add = app.buttons["discover.web.info.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        XCTAssertTrue(add.isHittable)
        XCTAssertTrue(app.buttons["discover.web.info.close"].isHittable)
        screenshot("Preview — information accessibility dark")
        app.buttons["discover.web.info.close"].tap()
        app.buttons["discover.web.more"].tap()
        app.buttons["discover.web.home"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Search results"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["discover.web.add"].isEnabled)
        app.buttons["discover.dismiss"].tap()
        XCTAssertTrue(app.textFields["discover.search"].waitForExistence(timeout: 3))
    }

    func testSavedLockedAppUsesAuthenticationGate() {
        app.terminate()
        app.launchArguments += ["--uitesting-locked-fixture"]
        app.launch()
        app.tabBars.buttons["Discover"].tap()
        search("Locked Fixture")
        app.buttons["discover.saved.Locked Fixture"].tap()
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.close"].exists)
    }

    func testLargeTextSearchKeepsAddActionReachable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        app.launch()
        app.tabBars.buttons["Discover"].tap()
        search("Notion")
        let add = app.buttons["discover.add.notion"]
        let dismissKeyboard = app.buttons["discover.dismissKeyboard"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 3))
        dismissKeyboard.tap()
        for _ in 0..<5 where !add.isHittable { app.swipeUp() }
        XCTAssertTrue(add.isHittable)
        screenshot("Discover — large text")
        add.tap()
        XCTAssertTrue(app.textFields["creation.name"].waitForExistence(timeout: 5))
    }

    private func search(_ text: String) {
        let field = app.textFields["discover.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(text)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Explicit live smoke test; provider availability is separate from deterministic UI coverage.
@MainActor
final class DiscoverLiveUITests: XCTestCase {
    func testLiveInternetSearchShowsResults() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["Discover"].tap()
        let search = app.textFields["discover.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Photopea\n")
        let result = app.webViews.links.matching(NSPredicate(format: "label CONTAINS[c] %@", "Photopea")).firstMatch
        let loaded = result.waitForExistence(timeout: 30)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Discover — live web search"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        if !loaded {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Live web search hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(loaded, "Expected live search results; inspect provider response if unavailable.")
        XCTAssertFalse(app.buttons["discover.web.add"].isEnabled)
    }
}
