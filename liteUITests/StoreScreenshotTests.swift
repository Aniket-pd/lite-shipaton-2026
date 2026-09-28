import XCTest

/// Run explicitly on iPhone Pro Max and iPad Pro to capture the real store UI.
@MainActor
final class StoreScreenshotTests: XCTestCase {
    func testCaptureStoreScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-groups-fixture", "--uitesting-live-purchases", "-lite.appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 10))
        capture(app, name: "01-profile-library")
        app.buttons["Groups"].firstMatch.tap()
        XCTAssertTrue(app.buttons["groups.menu.Work"].waitForExistence(timeout: 5))
        capture(app, name: "02-groups")
        app.buttons["Library"].firstMatch.tap()
        app.buttons["home.settings"].tap()
        app.buttons["settings.pro"].tap()
        XCTAssertTrue(app.buttons["pro.plan.aniket.lite.pro.monthly"].waitForExistence(timeout: 30))
        capture(app, name: "03-lite-pro")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
