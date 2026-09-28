import XCTest

@MainActor
final class ContainerProxyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-locked-fixture", "--uitesting-web-fixture"]
        app.launch()
    }

    func testProxyValidationPersistenceAndRestartGate() {
        // Establish the direct profile first; switching it must block until restart.
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 30))
        app.buttons["browser.close"].tap()
        app.buttons["home.app.Public Fixture"].press(forDuration: 1)
        app.buttons["App Settings"].tap()
        XCTAssertTrue(app.buttons["container.proxy"].waitForExistence(timeout: 5))
        app.buttons["container.proxy"].tap()
        app.switches["proxy.enabled"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let host = app.textFields["proxy.host"]
        XCTAssertTrue(host.waitForExistence(timeout: 3))
        host.tap()
        host.typeText("https://proxy.example.com")
        revealSave()
        app.buttons["proxy.save"].tap()
        XCTAssertTrue(app.staticTexts["proxy.error"].waitForExistence(timeout: 3))
        for _ in 0..<4 where !host.isHittable { app.swipeDown() }
        host.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let old = host.value as? String ?? ""
        host.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        host.typeText("proxy.example.com")
        revealSave()
        app.buttons["proxy.save"].tap()
        XCTAssertTrue(app.staticTexts["proxy.saved"].waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Encrypted proxy settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.proxy"].tap()
        XCTAssertEqual(app.switches["proxy.enabled"].value as? String, "1")
        XCTAssertEqual(app.textFields["proxy.host"].value as? String, "proxy.example.com")
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.done"].tap()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.staticTexts["Proxy setup required"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.webViews.staticTexts["Browser fixture"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Quit Lite from the app switcher")).firstMatch.exists)
    }

    private func revealSave() {
        XCTAssertTrue(app.buttons["proxy.save"].isHittable)
    }
}
