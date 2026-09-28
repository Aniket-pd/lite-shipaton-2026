import XCTest

@MainActor
final class SavedContentUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting", "--uitesting-web-fixture", "--uitesting-locked-fixture",
            "--uitesting-saved-fixture"
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Saved"].waitForExistence(timeout: 5))
    }

    override func tearDownWithError() throws {
        if let testRun, testRun.failureCount > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Saved content failure hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            attach("Saved content failure")
        }
    }

    func testGlobalLibraryHidesLockedContentAndOmitsEmptyLockedContainers() {
        openSaved()
        XCTAssertTrue(bookmark(named: "Public saved article").waitForExistence(timeout: 5))
        assertAvailableLockedContainers()
        assertProtectedContentIsHidden()

        search(for: "Confidential")
        XCTAssertFalse(bookmark(named: "Public saved article").exists)
        assertAvailableLockedContainers()
        assertProtectedContentIsHidden()
        attach("Locked bookmarks stay private in search")

        clearSearch()
        selectKind("Downloads")
        XCTAssertTrue(download(named: "public-guide.txt").waitForExistence(timeout: 5))
        assertAvailableLockedContainers()
        assertProtectedContentIsHidden()

        search(for: "confidential-report")
        XCTAssertFalse(download(named: "public-guide.txt").exists)
        assertAvailableLockedContainers()
        assertProtectedContentIsHidden()
        attach("Locked downloads stay private in search")
    }

    func testTappingSavedResultsDismissesSearchKeyboard() {
        openSaved()
        let search = app.textFields["saved.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))

        let sectionHeader = app.staticTexts["Today"]
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 3))
        sectionHeader.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }

    func testLockedSavedContainerRequiresAuthenticationBeforeShowingItems() {
        openSaved()
        app.buttons["saved.containerFilter"].tap()
        app.buttons["saved.filter.Locked Fixture"].tap()
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.close"].exists)
        XCTAssertFalse(bookmark(named: "Confidential saved article").exists)
        XCTAssertFalse(download(named: "confidential-report.txt").exists)
        XCTAssertFalse(app.buttons["saved.done"].exists,
                       "Protected Saved content must not be mounted before authentication")
        XCTAssertFalse(app.textFields["saved.search"].isHittable,
                       "The public search field behind the lock screen must not be interactive")
        attach("Saved container requires authentication")

        app.buttons["Done"].firstMatch.tap()
        XCTAssertFalse(app.buttons["saved.locked.Empty Locked Fixture"].exists)
        app.buttons["saved.containerFilter"].tap()
        XCTAssertFalse(app.buttons["saved.filter.Empty Locked Fixture"].exists)
    }

    func testSwitchingFromGlobalBookmarkToLockedContainerReplacesItsBrowser() {
        openSaved()
        let article = bookmark(named: "Public saved article")
        XCTAssertTrue(article.waitForExistence(timeout: 5))
        article.tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 25))

        app.buttons["browser.more"].tap()
        app.buttons["Switch Lite App"].tap()
        let lockedContainer = app.buttons["browser.switch.Locked Fixture"]
        XCTAssertTrue(lockedContainer.waitForExistence(timeout: 3))
        lockedContainer.tap()

        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.webViews.firstMatch.waitForNonExistence(timeout: 5),
                      "Switching containers must remove the previous browser before requiring authentication")
        XCTAssertFalse(app.buttons["browser.close"].exists)
        assertProtectedContentIsHidden()
        attach("Switch from Saved requires the new container's lock")

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.textFields["saved.search"].waitForExistence(timeout: 5))
        XCTAssertTrue(article.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lock.unlock"].exists)
        XCTAssertFalse(app.webViews.firstMatch.exists)

        // Reopening proves the old Saved presentation and switch request have
        // both been dismissed, leaving the root usable rather than obscured.
        article.tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 25))
        app.buttons["browser.close"].tap()
        XCTAssertTrue(article.waitForExistence(timeout: 5))
    }

    func testSavedControlsRemainReachableAtLargestAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openSaved()

        for title in ["Bookmarks", "Downloads"] {
            let segment = app.buttons["saved.kind.\(title.lowercased())"]
            XCTAssertTrue(segment.waitForExistence(timeout: 3))
            XCTAssertTrue(segment.isHittable, "The \(title) segment must remain reachable")
        }
        let filter = app.buttons["saved.containerFilter"]
        XCTAssertTrue(filter.isHittable)
        filter.tap()
        let publicContainer = app.buttons["saved.filter.Public Fixture"]
        XCTAssertTrue(publicContainer.waitForExistence(timeout: 3))
        publicContainer.tap()
        XCTAssertTrue(bookmark(named: "Public saved article").waitForExistence(timeout: 5))
        XCTAssertTrue(bookmark(named: "Public saved article").isHittable)
        attach("Saved bookmarks at largest accessibility size")

        selectKind("Downloads")
        let file = download(named: "public-guide.txt")
        XCTAssertTrue(file.waitForExistence(timeout: 5))
        XCTAssertTrue(file.isHittable)
        let fileID = String(file.identifier.dropFirst("saved.download.".count))
        let actions = app.buttons["saved.download.actions.\(fileID)"]
        XCTAssertTrue(actions.isHittable)
        // CGRect coordinates can round a 44-point target to 43.99999999999994.
        XCTAssertGreaterThanOrEqual(actions.frame.height + 0.001, 44)
        XCTAssertLessThanOrEqual(actions.frame.maxX, app.frame.maxX)
        actions.tap()
        let export = app.buttons["saved.download.export.\(fileID)"]
        XCTAssertTrue(export.waitForExistence(timeout: 3))
        XCTAssertTrue(export.isHittable)
        attach("Saved download actions at largest accessibility size")
    }

    func testCompactLayoutSearchSortingAndContainerScope() {
        app.terminate()
        app.launchArguments.append("--uitesting-saved-layout-fixture")
        app.launch()
        openSaved()
        let bookmarksTab = app.buttons["saved.kind.bookmarks"]
        XCTAssertLessThan(bookmarksTab.frame.minY, 120, "The section switch should start just below the status bar")
        XCTAssertTrue(bookmarksTab.isSelected)
        let filter = app.buttons["saved.containerFilter"]
        XCTAssertTrue(filter.isHittable)
        XCTAssertEqual(filter.frame.midY, bookmarksTab.frame.midY, accuracy: 1)
        XCTAssertGreaterThan(app.textFields["saved.search"].frame.minY, filter.frame.maxY)
        XCTAssertGreaterThanOrEqual(bookmarksTab.frame.height + 0.001, 44)
        XCTAssertTrue(app.staticTexts["Today"].exists)
        attach("Compact Saved bookmarks")

        app.buttons["saved.containerFilter"].tap()
        app.buttons["saved.filter.Public Fixture"].tap()
        XCTAssertTrue(bookmarkButtons.element(boundBy: 0).label.contains("Guide 2"))
        app.buttons["saved.containerFilter"].tap()
        app.buttons["saved.sort.name"].tap()
        XCTAssertTrue(bookmarkButtons.element(boundBy: 0).label.contains("Alpha reference"))
        XCTAssertLessThan(bookmark(named: "Guide 2").frame.minY, bookmark(named: "Guide 10").frame.minY,
                          "Names should use natural numeric ordering")
        XCTAssertFalse(bookmark(named: "Alpha reference").label.contains("Public Fixture"),
                       "The selected container need not be repeated on every row")

        search(for: "reference")
        XCTAssertEqual(bookmarkButtons.count, 2)
        clearSearch()
        selectKind("Downloads")
        let active = download(named: "design-assets.zip")
        XCTAssertTrue(active.waitForExistence(timeout: 3))
        XCTAssertLessThan(active.frame.minY, download(named: "Guide 2.txt").frame.minY,
                         "Active downloads stay above completed files even when sorting by name")
        XCTAssertLessThan(download(named: "Guide 2.txt").frame.minY, download(named: "Guide 10.txt").frame.minY)
        XCTAssertEqual(app.textFields["saved.search"].placeholderValue, "Search downloads")
        XCTAssertTrue(app.buttons["saved.kind.downloads"].isSelected)
        XCTAssertTrue(app.buttons["saved.filter.reset"].isHittable)
        attach("Compact Saved downloads")

        search(for: "missing-file")
        XCTAssertFalse(download(named: "Guide 2.txt").exists)
        XCTAssertTrue(app.buttons["saved.containerFilter"].isHittable)
        clearSearch()
        XCTAssertTrue(download(named: "Guide 2.txt").exists)
        app.buttons["saved.filter.reset"].tap()
        XCTAssertFalse(app.buttons["saved.filter.reset"].exists)
        XCTAssertTrue(download(named: "public-guide.txt").label.contains("Public Fixture"))
        attach("Minimal Saved downloads")

        app.terminate()
        app.launchArguments += ["-lite.appearance", "dark"]
        app.launch()
        openSaved()
        XCTAssertTrue(bookmark(named: "Guide 2").waitForExistence(timeout: 5))
        attach("Minimal Saved dark")
    }

    func testLockedOnlyLibraryExplainsWhereToUnlock() {
        app.terminate()
        app.launchArguments.append("--uitesting-saved-locked-only")
        app.launch()
        openSaved()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "filter above")).firstMatch.exists)
        XCTAssertEqual(bookmarkButtons.count, 0)
        assertAvailableLockedContainers()
        selectKind("Downloads")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "filter above")).firstMatch.exists)
        assertAvailableLockedContainers()
        assertProtectedContentIsHidden()
        attach("Locked-only Saved library")
    }

    func testBookmarkPageAppearsInContainerAndGlobalLibraryWithoutLosingBrowserState() {
        openBrowser()
        let editedNote = editBrowserNote()
        app.buttons["browser.more"].tap()
        let save = app.buttons["browser.bookmarkPage"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        openBrowserSaved("browser.savedBookmarks")
        let savedPage = bookmark(named: "Browser fixture")
        XCTAssertTrue(savedPage.waitForExistence(timeout: 5))
        XCTAssertTrue(bookmark(named: "Public saved article").exists)
        XCTAssertFalse(app.buttons["saved.locked.Locked Fixture"].exists,
                       "Browser Saved is scoped to its current container")
        assertProtectedContentIsHidden()
        attach("Bookmarked page in its container")

        app.buttons["saved.done"].tap()
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.webViews.textFields["Your note"].value as? String, editedNote,
                       "Opening Saved must preserve edited page state instead of reloading the browser")
        app.buttons["browser.more"].tap()
        XCTAssertEqual(app.buttons["browser.bookmarkPage"].label, "Page Bookmarked")
        // Dismiss the menu without selecting another browser action.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        app.buttons["browser.close"].tap()

        openSaved()
        XCTAssertTrue(bookmark(named: "Browser fixture").waitForExistence(timeout: 5))
        XCTAssertEqual(bookmarkButtons.count, 2,
                       "A page is saved once, and private bookmarks stay outside the global list")

        relaunchPreservingSaved()
        openSaved()
        XCTAssertTrue(bookmark(named: "Browser fixture").waitForExistence(timeout: 5),
                      "A bookmarked page must survive restarting Lite")
        bookmark(named: "Browser fixture").tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.buttons["browser.close"].exists)
    }

    func testBrowserDownloadRemainsAvailableAfterClosingItsContainer() {
        openBrowser()
        let editedNote = editBrowserNote()
        let downloadButton = app.webViews.buttons["Download file"]
        for _ in 0..<4 where !downloadButton.isHittable { app.webViews.firstMatch.swipeUp() }
        downloadButton.tap()
        XCTAssertTrue(app.buttons["browser.viewSavedDownload"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Save"].exists, "Completing a download should keep it in Lite")
        app.buttons["browser.viewSavedDownload"].tap()
        let completedFile = download(named: "lite-fixture.txt")
        XCTAssertTrue(completedFile.waitForExistence(timeout: 5))
        XCTAssertTrue(download(named: "public-guide.txt").exists)
        completedFile.tap()
        closeLoadedPreview(filename: "lite-fixture.txt", returningTo: app.buttons["saved.done"])
        app.buttons["saved.done"].tap()
        assertHittable(app.buttons["browser.close"])
        XCTAssertEqual(app.webViews.textFields["Your note"].value as? String, editedNote,
                       "Previewing a download must preserve the original browser's edited page state")
        app.buttons["browser.close"].tap()
        assertHittable(app.tabBars.buttons["Saved"])

        openSaved()
        selectKind("Downloads")
        XCTAssertTrue(download(named: "lite-fixture.txt").waitForExistence(timeout: 5),
                      "Closing the browser must preserve completed downloads")
        assertProtectedContentIsHidden()
        attach("Completed download in Saved")

        relaunchPreservingSaved()
        openSaved()
        selectKind("Downloads")
        XCTAssertTrue(download(named: "lite-fixture.txt").waitForExistence(timeout: 5),
                      "A completed download must survive restarting Lite")
        assertProtectedContentIsHidden()
    }

    func testSavedDownloadCanBePreviewedAndCancellingExportKeepsOriginal() {
        openSaved()
        selectKind("Downloads")
        let file = download(named: "public-guide.txt")
        XCTAssertTrue(file.waitForExistence(timeout: 5))
        let fileID = String(file.identifier.dropFirst("saved.download.".count))

        file.tap()
        closeLoadedPreview(filename: "public-guide.txt", returningTo: app.buttons["saved.download.actions.\(fileID)"],
                           screenshotName: "Saved download preview")

        app.buttons["saved.download.actions.\(fileID)"].tap()
        let export = app.buttons["saved.download.export.\(fileID)"]
        XCTAssertTrue(export.waitForExistence(timeout: 3))
        export.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 12), "Save a Copy should open the native Files destination picker")
        attach("Explicitly saving a copy to Files")
        // Files can restore a nested location with a Browse button instead of
        // Cancel. Dismiss its native sheet using the standard downward gesture.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(app.buttons["Save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(file.waitForExistence(timeout: 5), "Cancelling export must keep the original download in Lite")

        assertHittable(file)
        file.tap()
        closeLoadedPreview(filename: "public-guide.txt", returningTo: file)
        assertProtectedContentIsHidden()
    }

    private func openSaved() {
        app.tabBars.buttons["Saved"].tap()
        let field = app.textFields["saved.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(field.isHittable, "Search should be visible immediately, without pulling down a title bar")
        XCTAssertFalse(app.navigationBars.firstMatch.isHittable, "Saved should not reserve a navigation-title row")
    }

    private func relaunchPreservingSaved() {
        app.terminate()
        app.launchArguments.append("--uitesting-preserve-saved")
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Saved"].waitForExistence(timeout: 5))
    }

    private func openBrowser() {
        app.tabBars.buttons["Library"].tap()
        let group = app.buttons["home.app.Example"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        group.tap()
        let profile = app.buttons["profiles.profile.Public Fixture"]
        XCTAssertTrue(profile.waitForExistence(timeout: 3))
        profile.tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 3))
    }

    private func openBrowserSaved(_ identifier: String) {
        app.buttons["browser.more"].tap()
        let action = app.buttons[identifier]
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        action.tap()
        XCTAssertTrue(app.buttons["saved.done"].waitForExistence(timeout: 5))
    }

    private func editBrowserNote() -> String {
        let note = app.webViews.textFields["Your note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText(" edited")
        let editedValue = note.value as? String ?? ""
        XCTAssertTrue(editedValue.contains(" edited"), "The page must contain an actual edit before checking state preservation")
        app.webViews.staticTexts["Browser fixture"].tap()
        return editedValue
    }

    private func closeLoadedPreview(filename: String, returningTo control: XCUIElement, screenshotName: String? = nil) {
        // Quick Look exposes a temporary close button while its remote preview
        // is still loading. The filename toolbar appears when the real preview
        // is ready; interacting earlier can tap a disappearing placeholder.
        let title = (filename as NSString).deletingPathExtension
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 20),
                      "Quick Look must finish loading the file before closing it")
        let close = app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"]
        assertHittable(close)
        if let screenshotName { attach(screenshotName) }
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "Quick Look must fully dismiss before returning to Saved")
        assertHittable(control)
    }

    private func assertHittable(_ element: XCUIElement, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "The next control must be visible and interactive, not merely present behind a sheet", file: file, line: line)
    }

    private func selectKind(_ title: String) {
        let segment = app.buttons["saved.kind.\(title.lowercased())"]
        XCTAssertTrue(segment.waitForExistence(timeout: 3))
        segment.tap()
    }

    private func search(for text: String) {
        let field = app.textFields["saved.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(text)
    }

    private func clearSearch() {
        let clear = app.buttons["saved.search.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        clear.tap()
        if app.keyboards.buttons["Search"].isHittable { app.keyboards.buttons["Search"].tap() }
    }

    private var bookmarkButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", #"saved\.bookmark\.[0-9A-Fa-f-]+"#))
    }

    private func bookmark(named title: String) -> XCUIElement {
        bookmarkButtons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    private func download(named filename: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier MATCHES %@ AND label CONTAINS %@", #"saved\.download\.[0-9A-Fa-f-]+"#, filename)).firstMatch
    }

    private func assertAvailableLockedContainers(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.buttons["saved.locked.Locked Fixture"].exists,
                       "Locked containers belong in the filter, not in the content list", file: file, line: line)
        app.buttons["saved.containerFilter"].tap()
        let row = app.buttons["saved.filter.Locked Fixture"]
        XCTAssertTrue(row.waitForExistence(timeout: 3), "A locked container with saved content should remain in the filter", file: file, line: line)
        XCTAssertNil(row.label.range(of: #"\b\d+\b"#, options: .regularExpression),
                     "Locked placeholders must not expose item counts", file: file, line: line)
        XCTAssertFalse(app.buttons["saved.filter.Empty Locked Fixture"].exists,
                       "Empty locked containers should not appear in Saved", file: file, line: line)
        assertProtectedContentIsHidden(file: file, line: line)
        app.buttons["saved.filter.all"].tap()
    }

    private func assertProtectedContentIsHidden(file: StaticString = #filePath, line: UInt = #line) {
        for value in ["Confidential saved article", "confidential-report.txt", "Confidential saved download", "example.com/confidential"] {
            let exposed = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", value))
            XCTAssertEqual(exposed.count, 0, "Locked content must stay out of the accessibility tree: \(value)", file: file, line: line)
        }
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
