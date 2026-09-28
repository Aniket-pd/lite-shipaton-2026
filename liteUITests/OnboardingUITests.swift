import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-onboarding", "--uitesting-onboarding-reset"]
    }

    func testNavigationCompletionAndRelaunch() {
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding.title.library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.back"].isHittable)
        capture("Welcome")
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.webpage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Browse any website or webpage in Discover, then tap Add to Lite to save it to your library."].exists)
        capture("Add any webpage")
        app.buttons["onboarding.back"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.library"].waitForExistence(timeout: 3))
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.accounts"].waitForExistence(timeout: 3))
        capture("Separate accounts")
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.privacy"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.otherElements["onboarding.progress"].value as? String, "Page 4 of 5")
        capture("Face ID protection")
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.protection"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ad and tracker blocking is on by default for every profile. Block known ads and trackers as you browse."].exists)
        capture("Ad and tracker protection")
        app.buttons["onboarding.continue"].tap()
        assertStarterLibrary()
        app.terminate()
        app.launchArguments.removeAll { $0 == "--uitesting-onboarding-reset" }
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
    }

    func testSkipPersistsAndInterruptedIntroReturns() {
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--uitesting-onboarding-reset" }
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        assertStarterLibrary()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
    }

    func testAccessibilityTextKeepsActionsReachable() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for page in ["library", "webpage", "accounts", "privacy", "protection"] {
            XCTAssertTrue(app.staticTexts["onboarding.title.\(page)"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["onboarding.continue"].isHittable)
            if page != "library" { XCTAssertTrue(app.buttons["onboarding.back"].isHittable) }
            if page == "webpage" { capture("Accessibility text") }
            app.buttons["onboarding.continue"].tap()
        }
        assertStarterLibrary()
    }

    func testExistingLibraryBypassesIntro() {
        app.launchArguments += ["--uitesting-groups-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
    }

    func testIncomingLinkTakesPriorityOverIntro() {
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.open(URL(string: "lite://open/BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
        XCTAssertTrue(app.staticTexts["Lite App Not Found"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
    }

    func testReducedMotionKeepsTheSameCompletionPath() {
        app.launchArguments += ["--uitesting-reduce-motion"]
        app.launch()
        for page in ["library", "webpage", "accounts", "privacy", "protection"] {
            XCTAssertTrue(app.staticTexts["onboarding.title.\(page)"].waitForExistence(timeout: 5))
            if page == "accounts" { capture("Reduced motion") }
            app.buttons["onboarding.continue"].tap()
        }
        assertStarterLibrary()
    }

    func testSwipesNavigateBothWaysAndStopAtTheEnds() {
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding.title.library"].waitForExistence(timeout: 5))
        swipePage(forward: false)
        XCTAssertTrue(app.staticTexts["onboarding.title.library"].exists)
        for page in ["webpage", "accounts", "privacy", "protection"] {
            swipePage(forward: true)
            XCTAssertTrue(app.staticTexts["onboarding.title.\(page)"].waitForExistence(timeout: 3))
        }
        swipePage(forward: true)
        XCTAssertTrue(app.staticTexts["onboarding.title.protection"].exists)
        XCTAssertFalse(app.buttons["home.add"].exists)
        for page in ["privacy", "accounts", "webpage", "library"] {
            swipePage(forward: false)
            XCTAssertTrue(app.staticTexts["onboarding.title.\(page)"].waitForExistence(timeout: 3))
        }
    }

    func testVerticalAccessibilityScrollingDoesNotChangePageAndSwipingStillWorks() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--uitesting-reduce-motion"]
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding.title.library"].waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let before = app.staticTexts["onboarding.title.library"].frame.minY
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["onboarding.title.library"].exists)
        XCTAssertLessThan(app.staticTexts["onboarding.title.library"].frame.minY, before)
        XCTAssertTrue(app.buttons["onboarding.continue"].isHittable)
        swipePage(forward: true)
        XCTAssertTrue(app.staticTexts["onboarding.title.webpage"].waitForExistence(timeout: 3))
        app.buttons["onboarding.back"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.title.library"].waitForExistence(timeout: 3))
    }

    private func swipePage(forward: Bool) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.8 : 0.2, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.2 : 0.8, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func assertStarterLibrary() {
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["catalog.url"].exists)
        for name in ["Instagram", "Reddit", "X", "LinkedIn", "Gmail", "YouTube"] {
            XCTAssertTrue(app.buttons["home.app.\(name)"].exists, "Missing starter app: \(name)")
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
