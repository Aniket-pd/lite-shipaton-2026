import XCTest

@MainActor
final class GroupsCarouselUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--uitesting-groups-fixture", "--uitesting-web-fixture",
            "-lite.appearance", "dark", "-lite.atmosphericBackground", "YES"
        ]
        app.launch()
        app.tabBars.buttons["Groups"].tap()
        XCTAssertTrue(app.buttons["groups.menu.Work"].waitForExistence(timeout: 5))
    }

    func testCarouselSnapsLaunchesDirectlyAndKeepsEachGroupsPosition() {
        let work = app.scrollViews["groups.carousel.Work"]
        XCTAssertEqual(position("Work").label, "3 of 5")
        XCTAssertEqual(position("Social").label, "2 of 3")
        let headerFrame = app.buttons["groups.group.Work"].frame
        attach("Groups dark carousel")

        work.swipeLeft(velocity: .slow)
        XCTAssertTrue(waitUntil { self.position("Work").label != "3 of 5" })
        let selectedPosition = position("Work").label
        let index = Int(selectedPosition.prefix(1))! - 1
        let names = ["LinkedIn", "Gmail", "YouTube", "Reddit", "X"]
        let selected = work.buttons["groups.open.\(names[index])"]
        XCTAssertEqual(selected.frame.midX, work.frame.midX, accuracy: 3, "The focused app must snap to the center")
        XCTAssertEqual(app.buttons["groups.group.Work"].frame, headerFrame, "Scrolling apps must not move the group heading")
        XCTAssertEqual(position("Social").label, "2 of 3", "Each group must keep an independent scroll position")
        attach("Groups scrolled carousel")

        // A visible neighbour also launches with one tap, without a focus-only tap.
        let neighbour = work.buttons["groups.open.\(names[max(0, index - 1)])"]
        XCTAssertTrue(neighbour.isHittable)
        neighbour.tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 15))
        app.buttons["browser.close"].tap()
        XCTAssertTrue(app.buttons["groups.menu.Work"].waitForExistence(timeout: 3))
        XCTAssertEqual(position("Work").label, selectedPosition)

        app.tabBars.buttons["Library"].tap()
        app.tabBars.buttons["Groups"].tap()
        XCTAssertEqual(position("Work").label, selectedPosition)

        app.buttons["groups.group.Work"].tap()
        XCTAssertTrue(app.buttons["groups.detail.edit"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["groups.open.X"].exists, "The complete list remains available")
        app.buttons["groups.open.X"].tap()
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 5), "Group launching must preserve the biometric gate")
        XCTAssertFalse(app.webViews.firstMatch.exists)
    }

    func testExpandedGroupUsesHalfSheet() {
        app.buttons["groups.group.Work"].tap()
        XCTAssertTrue(app.buttons["groups.detail.edit"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["groups.detail.done"].exists)
        XCTAssertTrue(app.buttons["groups.open.X"].exists)
    }

    func testEmptyExpandedGroupExplainsHowToAddApps() {
        app.buttons["groups.group.Empty"].tap()
        XCTAssertTrue(app.staticTexts["This Group Is Empty"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Use Edit to add Lite Apps to this group."].exists)
        XCTAssertTrue(app.buttons["groups.detail.edit"].exists)
    }

    func testEditingTheFocusedAppAndDeletingAGroupPreservesLibraryApps() {
        let work = app.scrollViews["groups.carousel.Work"]
        work.swipeLeft(velocity: .slow)
        XCTAssertTrue(waitUntil { self.position("Work").label != "3 of 5" })
        let index = Int(position("Work").label.prefix(1))! - 1
        let removedName = ["LinkedIn", "Gmail", "YouTube", "Reddit", "X"][index]

        app.buttons["groups.menu.Work"].tap()
        app.buttons["Edit Group"].tap()
        XCTAssertTrue(app.buttons["groups.editor.app.\(removedName)"].waitForExistence(timeout: 3))
        app.buttons["groups.editor.app.\(removedName)"].tap()
        app.buttons["groups.editor.save"].tap()
        XCTAssertTrue(waitUntil { self.position("Work").label == "1 of 4" })
        XCTAssertFalse(work.buttons["groups.open.\(removedName)"].exists)
        XCTAssertEqual(work.buttons["groups.open.LinkedIn"].frame.midX, work.frame.midX, accuracy: 3)

        app.buttons["groups.menu.Work"].tap()
        app.buttons["Delete Group"].tap()
        let confirmation = app.sheets.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Delete Group"].tap()
        XCTAssertTrue(app.buttons["groups.menu.Work"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["groups.menu.Social"].exists)
        XCTAssertTrue(app.buttons["groups.addApps.Empty"].exists)

        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["home.app.LinkedIn"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.app.Gmail"].exists)
    }

    func testLightAppearanceAndAccessibilityTextKeepAppsReachable() {
        app.terminate()
        app.launchArguments += ["-lite.appearance", "light"]
        app.launch()
        app.tabBars.buttons["Groups"].tap()
        XCTAssertTrue(app.buttons["groups.menu.Work"].waitForExistence(timeout: 3))
        attach("Groups light carousel")

        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Groups"].tap()
        XCTAssertTrue(app.buttons["groups.menu.Work"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.scrollViews["groups.carousel.Work"].exists, "Accessibility text uses readable rows")
        let gmail = app.buttons["groups.open.Gmail"]
        XCTAssertTrue(gmail.isHittable)
        XCTAssertGreaterThanOrEqual(gmail.frame.height, 44)
        XCTAssertLessThanOrEqual(gmail.frame.maxX, app.frame.maxX)
        attach("Groups accessibility text")
        gmail.tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 15))
    }

    private func position(_ group: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "groups.position.\(group)").firstMatch
    }

    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)], timeout: 4) == .completed
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
