import SwiftUI
import WebKit
import XCTest
@testable import lite

@MainActor
final class BrowserAppearanceTests: XCTestCase {
    func testPalettePreservesColorAndChoosesReadableChrome() {
        XCTAssertEqual(BrowserPagePalette(pageColor: .black, websiteColorScheme: .light).colorScheme, .dark)
        XCTAssertEqual(BrowserPagePalette(pageColor: .white, websiteColorScheme: .dark).colorScheme, .light)
        let transparent = BrowserPagePalette(pageColor: .clear, websiteColorScheme: .dark)
        XCTAssertEqual(transparent.colorScheme, .dark)
        XCTAssertEqual(transparent.background.cgColor.alpha, 1)
        let palePage = UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1)
        XCTAssertEqual(BrowserPagePalette(pageColor: palePage, websiteColorScheme: .dark).background, palePage)
    }

    func testWebKitBackgroundFollowsPageChangesInsteadOfBrandThemeColor() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: configuration)
        let page = lite.WebPage(webView: webView)
        defer { page.tearDown() }
        webView.loadHTMLString("<html style='background:rgb(11,16,21)'><head><meta name='theme-color' content='#ff7700'></head><body>Color fixture</body></html>", baseURL: URL(string: "https://example.com"))
        try await waitForColor(page, red: 11.0 / 255, green: 16.0 / 255, blue: 21.0 / 255)
        _ = try await webView.evaluateJavaScript("document.documentElement.style.background = 'rgb(248,245,238)'")
        try await waitForColor(page, red: 248.0 / 255, green: 245.0 / 255, blue: 238.0 / 255)
        XCTAssertNotNil(webView.themeColor)
        XCTAssertNotEqual(page.pageBackgroundColor, webView.themeColor)
    }

    func testScrollDoesNotCollapseForSmallMovementsOrWhileTyping() {
        let state = BrowserChromeState()
        state.beginGesture()
        state.scroll(delta: 8, distanceFromTop: 120, canCollapse: true)
        state.scroll(delta: -9, distanceFromTop: 111, canCollapse: true)
        XCTAssertFalse(state.isCollapsed)
        state.beginGesture()
        state.scroll(delta: 90, distanceFromTop: 200, canCollapse: true)
        XCTAssertTrue(state.isCollapsed)
        state.beginGesture()
        state.scroll(delta: -30, distanceFromTop: 170, canCollapse: true)
        XCTAssertFalse(state.isCollapsed)
        state.isKeyboardVisible = true
        state.beginGesture()
        state.scroll(delta: 120, distanceFromTop: 300, canCollapse: true)
        XCTAssertFalse(state.isCollapsed)
    }

    func testScrollCanReverseWithinTheSameGestureWithoutJitter() {
        let state = BrowserChromeState()
        state.beginGesture()
        state.scroll(delta: 70, distanceFromTop: 200, canCollapse: true)
        XCTAssertTrue(state.isCollapsed)
        state.scroll(delta: -8, distanceFromTop: 192, canCollapse: true)
        XCTAssertTrue(state.isCollapsed, "Small corrections must not reopen controls")
        state.scroll(delta: -20, distanceFromTop: 172, canCollapse: true)
        XCTAssertFalse(state.isCollapsed, "A deliberate reversal must interrupt collapse")
        state.scroll(delta: 10, distanceFromTop: 182, canCollapse: true)
        XCTAssertFalse(state.isCollapsed)
        state.scroll(delta: 60, distanceFromTop: 242, canCollapse: true)
        XCTAssertTrue(state.isCollapsed)
        state.expand()
        XCTAssertFalse(state.isCollapsed, "Tapping the pill must always restore controls")
    }

    func testRequiredControlsAndTopOfPageOverrideCollapse() {
        let state = BrowserChromeState()
        state.scroll(delta: 70, distanceFromTop: 200, canCollapse: true)
        XCTAssertTrue(state.isCollapsed)
        state.scroll(delta: 1, distanceFromTop: 201, canCollapse: false)
        XCTAssertFalse(state.isCollapsed)
        state.scroll(delta: 70, distanceFromTop: 271, canCollapse: true)
        state.scroll(delta: -1, distanceFromTop: 2, canCollapse: true)
        XCTAssertFalse(state.isCollapsed)
        state.scroll(delta: .nan, distanceFromTop: 200, canCollapse: true)
        XCTAssertFalse(state.isCollapsed)
    }

    private func waitForColor(_ page: lite.WebPage, red: CGFloat, green: CGFloat, blue: CGFloat) async throws {
        for _ in 0..<100 {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if let color = page.pageBackgroundColor,
               color.getRed(&r, green: &g, blue: &b, alpha: &a),
               abs(r - red) < 0.01, abs(g - green) < 0.01, abs(b - blue) < 0.01 { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("The observed native color did not follow the rendered page")
    }
}
