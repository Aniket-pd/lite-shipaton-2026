import XCTest

@MainActor
final class LiteCreationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        app.launch()
    }

    func testCreationToolbarSizingAndValidation() {
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        app.buttons["home.add"].tap()
        let address = app.textFields["catalog.url"]
        let next = app.buttons["catalog.continue"]
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(address.waitForExistence(timeout: 3))
        XCTAssertFalse(next.isEnabled)
        XCTAssertEqual(next.frame.width, cancel.frame.width, accuracy: 1)
        XCTAssertEqual(next.frame.height, cancel.frame.height, accuracy: 1)
        let expectedSize = cancel.frame.size
        address.tap()
        address.typeText("example")
        XCTAssertFalse(next.isEnabled)
        address.typeText(".com")
        XCTAssertTrue(next.isEnabled)
        XCTAssertEqual(next.frame.width, expectedSize.width, accuracy: 1)
        XCTAssertEqual(next.frame.height, expectedSize.height, accuracy: 1)
        attachScreenshot(named: "Enabled blue Next")
        next.tap()
        let name = app.textFields["creation.name"]
        let create = app.buttons["creation.create"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(create.isEnabled)
        XCTAssertEqual(create.frame.width, expectedSize.width, accuracy: 1)
        XCTAssertEqual(create.frame.height, expectedSize.height, accuracy: 1)
        attachScreenshot(named: "Enabled blue Create")
        name.tap()
        let currentName = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentName.count))
        XCTAssertFalse(create.isEnabled)
        name.typeText("Work")
        XCTAssertTrue(create.isEnabled)
    }

    func testCompactCatalogRevealsMoreWebsites() {
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        app.buttons["home.add"].tap()
        let address = app.textFields["catalog.url"]
        XCTAssertTrue(address.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["catalog.continue"].isEnabled)
        XCTAssertTrue(app.buttons["catalog.service.gmail"].isHittable)
        attachScreenshot(named: "Compact website picker")

        app.buttons["catalog.more"].tap()
        let amazon = app.buttons["catalog.service.amazon"]
        XCTAssertTrue(amazon.waitForExistence(timeout: 3))
        amazon.tap()
        XCTAssertTrue(app.textFields["creation.name"].waitForExistence(timeout: 3))
        let preview = app.descendants(matching: .any).matching(identifier: "creation.preview").firstMatch
        XCTAssertTrue(preview.label.contains("Amazon"))
    }

    func testProfileAppearanceKeepsBadgeIndependentAndSavesCustomSymbol() {
        app.terminate()
        app.launchArguments += ["-lite.appearance", "dark"]
        app.launch()
        app.buttons["home.add"].tap()
        app.buttons["catalog.service.x"].tap()
        XCTAssertTrue(app.navigationBars["New profile"].waitForExistence(timeout: 3))

        let source = app.segmentedControls["creation.iconSource"]
        let orange = app.buttons["creation.badgeColor.orange"]
        XCTAssertTrue(source.buttons["Website"].isSelected)
        orange.tap()
        XCTAssertTrue(source.buttons["Website"].isSelected, "Changing badge color must keep website artwork")
        XCTAssertTrue(orange.isSelected)
        XCTAssertFalse(app.buttons["creation.icon.star"].exists)
        attachScreenshot(named: "New profile — website icon and orange badge")

        source.buttons["Custom"].tap()
        app.buttons["creation.icon.star"].tap()
        XCTAssertTrue(orange.isSelected)
        source.buttons["Website"].tap()
        source.buttons["Custom"].tap()
        XCTAssertTrue(app.buttons["creation.icon.star"].isSelected)
        XCTAssertTrue(orange.isSelected)
        attachScreenshot(named: "New profile — neutral custom icon and orange badge")
        app.buttons["creation.create"].tap()

        let tile = app.buttons["home.app.Personal"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.press(forDuration: 1)
        app.buttons["Edit"].tap()
        let editedSource = app.segmentedControls["edit.iconSource"]
        XCTAssertTrue(editedSource.waitForExistence(timeout: 3))
        XCTAssertTrue(editedSource.buttons["Custom"].isSelected)
        XCTAssertTrue(app.buttons["edit.icon.star"].isSelected)
        let savedOrange = app.buttons["edit.badgeColor.orange"]
        for _ in 0..<3 where !savedOrange.isHittable { app.swipeUp() }
        XCTAssertTrue(savedOrange.isSelected, "Saved badge color must survive reopening the editor")
    }

    func testProfileAppearanceAtAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                                "-lite.appearance", "light"]
        app.launch()
        app.buttons["home.add"].tap()
        let website = app.buttons["catalog.service.x"]
        for _ in 0..<4 where !website.isHittable { app.swipeUp() }
        website.tap()
        let source = app.segmentedControls["creation.iconSource"]
        for _ in 0..<5 where !source.isHittable { app.swipeUp() }
        source.buttons["Custom"].tap()
        let star = app.buttons["creation.icon.star"]
        for _ in 0..<3 where !star.isHittable { app.swipeUp() }
        star.tap()
        let orange = app.buttons["creation.badgeColor.orange"]
        for _ in 0..<4 where !orange.isHittable { app.swipeUp() }
        orange.tap()
        XCTAssertTrue(orange.isSelected)
        attachScreenshot(named: "Profile appearance — accessibility text size")
        XCTAssertTrue(app.buttons["creation.create"].isHittable)
        app.buttons["creation.create"].tap()
        XCTAssertTrue(app.buttons["home.app.Personal"].waitForExistence(timeout: 5))
    }

    func testCreatesTwoIndependentAppsForTheSameService() {
        createCatalogApp(service: "instagram", name: "Personal")
        createCatalogApp(service: "instagram", name: "Work", expectedTileName: "Instagram")

        XCTAssertFalse(app.buttons["home.app.Personal"].exists)
        XCTAssertFalse(app.buttons["home.app.Work"].exists)
        let groupedApp = app.buttons["home.app.Instagram"]
        XCTAssertTrue(groupedApp.exists)
        groupedApp.tap()
        XCTAssertTrue(app.buttons["profiles.profile.Personal"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profiles.profile.Work"].exists)
        attachScreenshot(named: "My Lite Apps")
        XCTAssertFalse(app.buttons["profiles.add"].exists)
        XCTAssertFalse(app.buttons["Done"].exists)
    }

    func testDiscoverCreatesMultipleAppsForTheSameWebsite() {
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.navigationBars["Discover"].waitForExistence(timeout: 5))

        for (index, name) in ["Personal", "Work"].enumerated() {
            let instagram = app.buttons["discover.service.instagram"]
            XCTAssertTrue(instagram.waitForExistence(timeout: 3))
            instagram.tap()
            let add = app.buttons["discover.detail.add"]
            XCTAssertTrue(add.waitForExistence(timeout: 3))
            add.tap()
            enterNameAndCreate(name)
            let tileIdentifier = index == 0 ? "home.app.Personal" : "home.app.Instagram"
            XCTAssertTrue(app.buttons[tileIdentifier].waitForExistence(timeout: 5))
            app.tabBars.buttons["Discover"].tap()
        }

        app.tabBars.buttons["Library"].tap()
        app.buttons["home.app.Instagram"].tap()
        XCTAssertTrue(app.buttons["profiles.profile.Personal"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profiles.profile.Work"].exists)
    }

    func testCreatesCustomWebsiteAndDeletesOnlyChosenApp() {
        createCatalogApp(service: "reddit", name: "Reddit")
        createCustomApp(address: "example.com", name: "Example")

        let customApp = app.buttons["home.app.Example"]
        XCTAssertTrue(customApp.waitForExistence(timeout: 5))
        customApp.press(forDuration: 1)
        app.buttons["Delete"].tap()
        let confirmation = app.sheets.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Delete"].tap()

        XCTAssertTrue(customApp.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.app.Reddit"].exists)
    }

    func testCreatesGroupAndOpensAnExistingApp() {
        app.terminate()
        app.launchArguments += ["--uitesting-locked-fixture", "--uitesting-web-fixture"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Groups"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Groups"].tap()
        XCTAssertTrue(app.navigationBars["Groups"].waitForExistence(timeout: 5))

        app.buttons["groups.empty.create"].tap()
        let name = app.textFields["groups.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("Daily")
        app.buttons["groups.editor.app.Public Fixture"].tap()
        app.buttons["groups.editor.app.Locked Fixture"].tap()
        app.buttons["groups.editor.save"].tap()

        let group = app.buttons["groups.group.Daily"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        group.tap()
        let publicApp = app.buttons["groups.open.Public Fixture"]
        XCTAssertTrue(publicApp.waitForExistence(timeout: 3))
        publicApp.tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 8))
        app.buttons["browser.close"].tap()
        XCTAssertTrue(app.buttons["groups.open.Public Fixture"].waitForExistence(timeout: 3))
    }

    func testOpensAndClosesAnAppWebView() {
        createCustomApp(address: "example.com", name: "Example")
        app.buttons["home.app.Example"].tap()
        let close = app.buttons["browser.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let pageHeading = app.webViews.staticTexts["Example Domain"]
        let rendered = pageHeading.waitForExistence(timeout: 25)
        attachScreenshot(named: "Lite App browser")
        if !rendered {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Browser rendering failure hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(rendered, "The live rendering smoke test requires HTTPS access to example.com and expects its heading within 25 seconds.")
        close.tap()
        XCTAssertTrue(app.buttons["home.app.Example"].waitForExistence(timeout: 5))
    }

    func testRefreshIconCanBeCancelledOrSaved() {
        createCatalogApp(service: "instagram", name: "Instagram")
        let tile = app.buttons["home.app.Instagram"]
        tile.press(forDuration: 1)
        app.buttons["Edit"].tap()
        let iconSource = app.segmentedControls["edit.iconSource"]
        XCTAssertTrue(iconSource.waitForExistence(timeout: 3))
        iconSource.buttons["Custom"].tap()
        XCTAssertTrue(iconSource.buttons["Custom"].isSelected)
        app.buttons["edit.save"].tap()

        tile.press(forDuration: 1)
        app.buttons["Edit"].tap()
        XCTAssertFalse(iconSource.buttons["Website"].isEnabled, "Saving the symbol must clear website artwork")
        app.buttons["edit.refreshIcon"].tap()
        XCTAssertTrue(app.staticTexts["Icon refreshed. Save to keep it."].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        tile.press(forDuration: 1)
        app.buttons["Edit"].tap()
        XCTAssertTrue(iconSource.buttons["Custom"].isSelected, "Cancelling must preserve the chosen symbol")
        app.buttons["edit.refreshIcon"].tap()
        XCTAssertTrue(app.staticTexts["Icon refreshed. Save to keep it."].waitForExistence(timeout: 3))
        attachScreenshot(named: "Refreshed catalog icon")
        app.buttons["edit.save"].tap()
        tile.press(forDuration: 1)
        app.buttons["Edit"].tap()
        XCTAssertTrue(iconSource.waitForExistence(timeout: 3))
        XCTAssertTrue(iconSource.buttons["Website"].isSelected)
    }

    func testCancellingCreationLeavesHomeEmpty() {
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Empty library")
        app.buttons["home.add"].tap()
        XCTAssertTrue(app.textFields["catalog.url"].waitForExistence(timeout: 3))
        attachScreenshot(named: "New Lite App catalog")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["home.empty.add"].waitForExistence(timeout: 3))
    }

    func testSwitchingAndCreatingAnotherAccountKeepsBrowserUsable() {
        createCustomApp(address: "example.com", name: "Personal")
        createCustomApp(address: "example.com", name: "Work", expectedTileName: "Example")
        app.buttons["home.app.Example"].tap()
        app.buttons["profiles.profile.Personal"].tap()
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 5))
        app.buttons["browser.more"].tap()
        app.buttons["Switch Lite App"].tap()
        app.buttons["browser.switch.Work"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Work, ")).firstMatch.waitForExistence(timeout: 8))
        app.buttons["browser.more"].tap()
        app.buttons["Create Another Account"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Work Account, ")).firstMatch.waitForExistence(timeout: 8))
        app.buttons["browser.close"].tap()
        let groupedApp = app.buttons["home.app.Example"]
        XCTAssertTrue(groupedApp.waitForExistence(timeout: 5))
        groupedApp.tap()
        XCTAssertTrue(app.buttons["profiles.profile.Personal"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profiles.profile.Work"].exists)
        let workAccount = app.buttons["profiles.profile.Work Account"]
        for _ in 0..<3 where !workAccount.exists { app.swipeUp() }
        XCTAssertTrue(workAccount.exists)
    }

    func testEditingAndSearchingLibrary() {
        createCustomApp(address: "example.com", name: "Original")
        app.buttons["home.app.Original"].press(forDuration: 1)
        app.buttons["Edit"].tap()
        let name = app.textFields["edit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Original".count))
        name.typeText("Renamed")
        app.buttons["edit.save"].tap()
        XCTAssertTrue(app.buttons["home.app.Renamed"].waitForExistence(timeout: 5))
        app.swipeDown()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("missing")
        XCTAssertFalse(app.buttons["home.app.Renamed"].exists)
        search.buttons["Clear text"].tap()
        search.typeText("Renamed")
        XCTAssertTrue(app.buttons["home.app.Renamed"].exists)
        attachScreenshot(named: "V2 search")
    }

    func testNativeUploadDownloadPopupAndDialogControls() {
        app.terminate()
        app.launchArguments += ["--uitesting-web-fixture", "--uitesting-locked-fixture"]
        app.launch()
        app.buttons["home.app.Example"].tap()
        let publicProfile = app.buttons["profiles.profile.Public Fixture"]
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 5))
        publicProfile.tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 25))
        app.webViews.buttons["Show dialog"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Fixture message"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()
        app.webViews.links["Open window"].tap()
        XCTAssertTrue(app.buttons["browser.openWindow"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].exists)
        app.buttons["browser.openWindow"].tap()
        XCTAssertTrue(app.buttons["browser.closeWindow"].waitForExistence(timeout: 3))
        app.buttons["browser.closeWindow"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].exists)
        app.webViews.buttons["Download file"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Download link clicked blob"].waitForExistence(timeout: 2), app.debugDescription)
        XCTAssertTrue(app.buttons["browser.viewSavedDownload"].waitForExistence(timeout: 12))
        app.buttons["browser.viewSavedDownload"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved.download.actions.")).firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        app.buttons["Save a Copy to Files"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5), "Native Files export must be presented on request")
        attachScreenshot(named: "V2 Files export")
        app.buttons["Save"].tap()
        if app.alerts.buttons["Replace"].waitForExistence(timeout: 2) {
            app.alerts.buttons["Replace"].tap()
        }
        XCTAssertTrue(app.buttons["Save"].waitForNonExistence(timeout: 5))
        app.buttons["saved.done"].tap()
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 5))
        let upload = app.webViews.buttons["Upload a file"]
        XCTAssertTrue(upload.exists, app.debugDescription)
        upload.tap()
        let chooseFile = app.buttons["Choose File"]
        XCTAssertTrue(chooseFile.waitForExistence(timeout: 5), app.debugDescription)
        chooseFile.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5), "Native Files import must be presented")
        attachScreenshot(named: "V2 Files import")
        app.buttons["Cancel"].firstMatch.tap()
        app.buttons["browser.close"].tap()
    }

    /// A separate, explicitly selected live audit. Attachments record provider
    /// responses; success here does not certify sign-in or authenticated pages.
    func testCatalogPublicLandingPages() {
        for (service, name) in [("linkedin", "LinkedIn"), ("instagram", "Instagram"), ("reddit", "Reddit"), ("x", "X"), ("gmail", "Gmail"), ("amazon", "Amazon"), ("youtube", "YouTube")] {
            createCatalogApp(service: service, name: name)
            app.buttons["home.app.\(name)"].tap()
            XCTAssertTrue(app.buttons["browser.close"].waitForExistence(timeout: 5))
            _ = app.webViews.staticTexts.firstMatch.waitForExistence(timeout: 20)
            attachScreenshot(named: "Public landing — \(name)")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Public landing hierarchy — \(name)"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            if service == "linkedin" {
                let signIn = app.webViews.links.matching(NSPredicate(format: "label CONTAINS[c] %@", "sign in")).firstMatch
                if signIn.exists {
                    signIn.tap()
                    _ = app.webViews.textFields.firstMatch.waitForExistence(timeout: 15)
                    attachScreenshot(named: "LinkedIn sign-in")
                    let signInHierarchy = XCTAttachment(string: app.debugDescription)
                    signInHierarchy.name = "LinkedIn sign-in hierarchy"
                    signInHierarchy.lifetime = .keepAlways
                    add(signInHierarchy)
                }
                app.buttons["browser.more"].tap()
                app.descendants(matching: .any).matching(identifier: "browser.protection").firstMatch.tap()
                app.buttons["browser.more"].tap()
                app.buttons["Go to Start Page"].tap()
                _ = app.webViews.staticTexts["Welcome to your professional community"].waitForExistence(timeout: 15)
                attachScreenshot(named: "LinkedIn protection disabled")
                let noProtection = XCTAttachment(string: app.debugDescription)
                noProtection.name = "LinkedIn protection disabled hierarchy"
                noProtection.lifetime = .keepAlways
                add(noProtection)
            }
            app.buttons["browser.close"].tap()
            XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        }
    }

    func testGridSwitcherAndDeepLinkAllEnforceLock() {
        app.terminate()
        app.launchArguments += ["--uitesting-locked-fixture", "--uitesting-web-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["home.app.Locked Fixture"].waitForExistence(timeout: 5))
        app.buttons["home.app.Locked Fixture"].tap()
        assertLockedWithoutBrowser()
        app.buttons["Done"].tap()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.buttons["browser.more"].waitForExistence(timeout: 5))
        app.buttons["browser.more"].tap()
        app.buttons["Switch Lite App"].tap()
        app.buttons["browser.switch.Locked Fixture"].tap()
        assertLockedWithoutBrowser()
        app.buttons["Done"].tap()
        app.buttons["home.app.Public Fixture"].press(forDuration: 1)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.textFields["edit.name"].waitForExistence(timeout: 3))
        app.open(URL(string: "lite://open/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA2")!)
        assertLockedWithoutBrowser()
        app.buttons["Done"].tap()
        app.open(URL(string: "lite://open/BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
        XCTAssertTrue(app.staticTexts["Lite App Not Found"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.close"].exists)
    }

    func testLongPressMenuShowsMatchingLockAction() {
        app.terminate()
        app.launchArguments += ["--uitesting-locked-fixture"]
        app.launch()

        let publicApp = app.buttons["home.app.Public Fixture"]
        XCTAssertTrue(publicApp.waitForExistence(timeout: 5))
        publicApp.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Require Face ID"].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        let lockedApp = app.buttons["home.app.Locked Fixture"]
        XCTAssertTrue(lockedApp.waitForExistence(timeout: 5))
        lockedApp.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Unlock App"].waitForExistence(timeout: 3))
    }

    func testContainerPreferencesDataResetAndDiagnostics() {
        launchContainerFixture()
        openContainerDetails("Public Fixture")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Not recorded yet")).firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: "Container details — real empty profile")
        app.buttons["container.preferences"].tap()
        app.buttons["preferences.layout"].tap()
        app.buttons["Desktop"].tap()
        assertContainerControl("preferences.layout", contains: "Desktop")
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.privacy"].tap()
        app.buttons["preferences.camera"].tap()
        app.buttons["Block"].tap()
        assertContainerControl("preferences.camera", contains: "Block")
        attachScreenshot(named: "Container preferences")
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.done"].tap()
        openContainerDetails("Public Fixture")
        app.buttons["container.preferences"].tap()
        assertContainerControl("preferences.layout", contains: "Desktop")
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.privacy"].tap()
        assertContainerControl("preferences.camera", contains: "Block")
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.data"].tap()
        XCTAssertTrue(app.staticTexts["data.empty"].waitForExistence(timeout: 30))
        attachScreenshot(named: "Container website data — empty state")
        let reset = app.buttons["data.reset"]
        for _ in 0..<3 where !reset.isHittable { app.swipeUp() }
        reset.tap()
        app.buttons["Reset Preferences"].tap()
        let resetMessage = app.staticTexts["Container preferences reset. Website data and the biometric lock were kept."]
        for _ in 0..<3 where !resetMessage.exists { app.swipeUp() }
        // A cold WebKit blocklist compilation can take longer than a UI transition.
        XCTAssertTrue(resetMessage.waitForExistence(timeout: 90))
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.preferences"].tap()
        assertContainerControl("preferences.layout", contains: "Mobile")
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.privacy"].tap()
        assertContainerControl("preferences.camera", contains: "Ask")
        app.navigationBars.buttons["App Settings"].tap()
        openContainerDiagnostics()
        XCTAssertTrue(app.staticTexts["No navigation error recorded"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Container diagnostics — no invented connection")
    }

    func testContainerDataClearAndActualNavigationDiagnostics() {
        launchContainerFixture()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].waitForExistence(timeout: 8))
        app.webViews.buttons["Store website data"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Stored website data"].waitForExistence(timeout: 3))
        app.buttons["browser.close"].tap()
        openContainerDetails("Public Fixture")
        openContainerDiagnostics()
        assertContainerControl("diagnostics.host", contains: "example.com")
        assertContainerControl("diagnostics.connection", contains: "Not fully encrypted")
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.data"].tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "example.com")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.staticTexts["Local storage"].waitForExistence(timeout: 5))
        app.buttons["Remove This Website’s Data"].tap()
        XCTAssertTrue(app.buttons["Clear Data"].waitForExistence(timeout: 3), app.debugDescription)
        app.buttons["Clear Data"].tap()
        XCTAssertTrue(app.staticTexts["data.empty"].waitForExistence(timeout: 10))
        let clear = app.buttons["data.clearAll"]
        for _ in 0..<3 where !clear.isHittable { app.swipeUp() }
        clear.tap()
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.otherElements["PopoverDismissRegion"].tap() }
        XCTAssertTrue(clear.exists)
        clear.tap()
        app.buttons["Clear Data"].tap()
        XCTAssertTrue(app.staticTexts["Website-data cleanup completed. The records below have been refreshed."].waitForExistence(timeout: 10))
        app.navigationBars.buttons["App Settings"].tap()
        openContainerDiagnostics()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Not recorded yet")).firstMatch.waitForExistence(timeout: 5))
    }

    func testAdvancedContainerControlsAffectWebsiteWindowsAndScripts() {
        launchContainerFixture()
        openContainerDetails("Public Fixture")
        app.buttons["container.preferences"].tap()
        let advanced = app.buttons["preferences.advanced"]
        for _ in 0..<4 where !advanced.isHittable { app.swipeUp() }
        advanced.tap()
        let popups = app.switches["preferences.popups"]
        XCTAssertTrue(popups.waitForExistence(timeout: 3))
        popups.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.navigationBars.buttons["Browsing"].tap()
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.done"].tap()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.links["Open window"].waitForExistence(timeout: 8))
        app.webViews.links["Open window"].tap()
        XCTAssertTrue(app.staticTexts["browser.protectionNotice"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.webViews.staticTexts["Browser fixture"].exists)
        XCTAssertFalse(app.buttons["browser.closeWindow"].exists)
        app.buttons["browser.close"].tap()
        openContainerDetails("Public Fixture")
        app.buttons["container.preferences"].tap()
        for _ in 0..<4 where !advanced.isHittable { app.swipeUp() }
        advanced.tap()
        let javascript = app.switches["preferences.javascript"]
        javascript.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.navigationBars.buttons["Browsing"].tap()
        app.navigationBars.buttons["App Settings"].tap()
        app.buttons["container.done"].tap()
        app.buttons["home.app.Public Fixture"].tap()
        XCTAssertTrue(app.webViews.buttons["Show dialog"].waitForExistence(timeout: 8))
        app.webViews.buttons["Show dialog"].tap()
        XCTAssertFalse(app.alerts.staticTexts["Fixture message"].waitForExistence(timeout: 2))
        app.buttons["browser.close"].tap()
    }

    func testContainerDetailsRequiresAuthenticationForLockedApp() {
        launchContainerFixture()
        app.buttons["home.app.Locked Fixture"].press(forDuration: 1)
        app.buttons["App Settings"].tap()
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["container.data"].exists)
        XCTAssertFalse(app.buttons["container.preferences"].exists)
        XCTAssertFalse(app.buttons["container.diagnostics"].exists)
    }

    private func assertContainerControl(_ identifier: String, contains value: String) {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue("\(element.label) \(element.value as? String ?? "")".contains(value), app.debugDescription)
    }

    private func launchContainerFixture() {
        app.terminate()
        app.launchArguments += ["--uitesting-locked-fixture", "--uitesting-web-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["home.app.Public Fixture"].waitForExistence(timeout: 5))
    }

    private func openContainerDetails(_ name: String) {
        app.buttons["home.app.\(name)"].press(forDuration: 1)
        app.buttons["App Settings"].tap()
        XCTAssertTrue(app.buttons["container.preferences"].waitForExistence(timeout: 5))
    }

    private func openContainerDiagnostics() {
        let diagnostics = app.buttons["container.diagnostics"]
        for _ in 0..<4 where !diagnostics.isHittable { app.swipeUp() }
        XCTAssertTrue(diagnostics.isHittable)
        diagnostics.tap()
    }

    private func assertLockedWithoutBrowser() {
        XCTAssertTrue(app.buttons["lock.unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.close"].exists)
        XCTAssertFalse(app.webViews.staticTexts["Browser fixture"].exists)
    }

    private func createCustomApp(address: String, name: String, expectedTileName: String? = nil) {
        let add = app.buttons["home.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let url = app.textFields["catalog.url"]
        XCTAssertTrue(url.waitForExistence(timeout: 3))
        url.tap()
        url.typeText(address)
        app.buttons["catalog.continue"].tap()
        enterNameAndCreate(name)
        XCTAssertTrue(app.buttons["home.app.\(expectedTileName ?? name)"].waitForExistence(timeout: 5))
    }

    private func createCatalogApp(service: String, name: String, expectedTileName: String? = nil) {
        let add = app.buttons["home.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let serviceButton = app.buttons["catalog.service.\(service)"]
        if !serviceButton.exists, app.buttons["catalog.more"].exists {
            app.buttons["catalog.more"].tap()
        }
        for _ in 0..<4 where !serviceButton.exists || !serviceButton.isHittable { app.swipeUp() }
        XCTAssertTrue(serviceButton.waitForExistence(timeout: 3))
        serviceButton.tap()
        enterNameAndCreate(name)
        XCTAssertTrue(app.buttons["home.app.\(expectedTileName ?? name)"].waitForExistence(timeout: 5))
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func enterNameAndCreate(_ name: String) {
        let nameField = app.textFields["creation.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        if name == "Instagram Personal" { attachScreenshot(named: "Create Lite App details") }
        nameField.tap()
        if let existing = nameField.value as? String, !existing.isEmpty {
            nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        nameField.typeText(name)
        let createButton = app.buttons["creation.create"]
        for _ in 0..<6 where !createButton.isHittable { app.swipeUp() }
        XCTAssertTrue(createButton.isHittable)
        createButton.tap()
    }
}
