import XCTest

/// Manual store integration check. Requires configured, propagated App Store products.
@MainActor
final class LiveProStoreUITests: XCTestCase {
    func testLiveOfferingShowsAllThreeLocalizedPlans() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--uitesting-live-purchases", "-lite.appearance", "light"]
        app.launch()
        app.buttons["home.settings"].tap()
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Settings — highlighted Lite Pro card"
        settings.lifetime = .keepAlways
        add(settings)
        app.buttons["settings.pro"].tap()
        XCTAssertTrue(app.buttons["pro.close"].waitForExistence(timeout: 5))
        let monthly = app.buttons["pro.plan.aniket.lite.pro.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 30), "App Store monthly product must be available")
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "Lite Pro — live App Store prices"
        top.lifetime = .keepAlways
        add(top)
        XCTAssertTrue(app.buttons["pro.plan.aniket.lite.pro.lifetime"].exists, "Lifetime must be available in StoreKit")
        XCTAssertTrue(app.buttons["pro.plan.aniket.lite.pro.weekly"].exists)
        XCTAssertTrue(monthly.isSelected)
        XCTAssertLessThan(app.buttons["pro.plan.aniket.lite.pro.weekly"].frame.minY, monthly.frame.minY)
        XCTAssertLessThan(monthly.frame.minY, app.buttons["pro.plan.aniket.lite.pro.lifetime"].frame.minY)
        let purchaseY = app.buttons["pro.purchase"].frame.minY
        let panelHeadingY = app.staticTexts["Choose your plan"].frame.minY
        let content = app.scrollViews["pro.content"]
        let terms = app.buttons["pro.terms"]
        XCTAssertGreaterThanOrEqual(app.buttons["pro.freePlanFAQ"].frame.minY,
                                    app.staticTexts["Choose your plan"].frame.minY - 20,
                                    "Supporting details start below the initial visible content")
        let start = content.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        let end = content.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
        start.press(forDuration: 0.1, thenDragTo: end)
        for _ in 0..<5 where terms.frame.maxY >= app.staticTexts["Choose your plan"].frame.minY {
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(app.buttons["pro.restore"].isHittable)
        XCTAssertTrue(terms.isHittable)
        XCTAssertTrue(app.buttons["pro.privacy"].isHittable)
        XCTAssertLessThan(terms.frame.maxY, app.staticTexts["Choose your plan"].frame.minY,
                          "Legal links must be visible above the purchase panel")
        XCTAssertEqual(app.buttons["pro.purchase"].frame.minY, purchaseY, accuracy: 2,
                       "The purchase panel stays anchored while supporting information scrolls")
        let footer = XCTAttachment(screenshot: app.screenshot())
        footer.name = "Lite Pro — FAQ and legal links above anchored plans"
        footer.lifetime = .keepAlways
        add(footer)
        let faq = app.buttons["pro.freePlanFAQ"]
        XCTAssertTrue(faq.isHittable)
        faq.tap()
        XCTAssertTrue(app.staticTexts["pro.freePlanDetails"].waitForExistence(timeout: 3))
        XCTAssertEqual(faq.value as? String, "Expanded")
        faq.tap()
        app.buttons["pro.plan.aniket.lite.pro.lifetime"].tap()
        for _ in 0..<3 where !app.buttons["pro.purchase"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["pro.purchase"].label.contains("Buy Lifetime"))
        XCTAssertTrue(app.buttons["pro.purchase"].label.contains("One-time purchase"))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "charged to your Apple Account")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["Choose your plan"].frame.minY, panelHeadingY, accuracy: 2)
        XCTAssertEqual(app.buttons["pro.purchase"].frame.minY, purchaseY, accuracy: 2)
        XCTAssertFalse(app.buttons["pro.manage"].exists, "Lifetime must not show subscription management copy")
        XCTAssertTrue(app.buttons["pro.restore"].exists)
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "Lite Pro — lifetime and purchase terms"
        details.lifetime = .keepAlways
        add(details)
        let weekly = app.buttons["pro.plan.aniket.lite.pro.weekly"]
        for _ in 0..<4 where !weekly.isHittable { app.swipeDown() }
        weekly.tap()
        XCTAssertTrue(weekly.isSelected)
        XCTAssertEqual(app.staticTexts["Choose your plan"].frame.minY, panelHeadingY, accuracy: 2)
        XCTAssertEqual(app.buttons["pro.purchase"].frame.minY, purchaseY, accuracy: 2)
        for _ in 0..<3 where !app.buttons["pro.purchase"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["pro.purchase"].label.contains("/week"))
        XCTAssertTrue(app.buttons["pro.manage"].exists)
    }
}
