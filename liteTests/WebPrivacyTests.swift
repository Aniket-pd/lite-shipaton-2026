import Foundation
import WebKit
import XCTest
@testable import lite

@MainActor
final class WebPrivacyTests: XCTestCase {
    func testPrivacyRulesCompileUsingPublicWebKitAPI() async throws {
        let rules = try await ContentBlocker.rules()
        XCTAssertEqual(rules.identifier, ContentBlocker.identifier)
    }

    func testBundledDomainRulesCoverAdsAndRedirectsWithoutSubstringFalsePositives() throws {
        XCTAssertGreaterThan(ContentBlocker.domains.count, 50_000)
        let data = Data(ContentBlocker.encodedRules.utf8)
        let rules = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let networkRules = rules.filter { ($0["action"] as? [String: Any])?["type"] as? String == "block" }
        let filters = try networkRules.map { rule in
            let trigger = try XCTUnwrap(rule["trigger"] as? [String: Any])
            XCTAssertNil(trigger["load-type"], "Ad documents and first-party ad hosts must also be blocked")
            XCTAssertNil(trigger["resource-type"], "Protection includes iframe and main documents")
            return try NSRegularExpression(pattern: XCTUnwrap(trigger["url-filter"] as? String), options: .caseInsensitive)
        }
        for address in ["https://doubleclick.net/ad", "https://stats.g.doubleclick.net/pixel", "https://DOUBLECLICK.NET.:443/ad", "https://popads.net/"] {
            let url = try XCTUnwrap(URL(string: address))
            XCTAssertTrue(ContentBlocker.blocks(url), address)
            XCTAssertTrue(filters.contains { $0.firstMatch(in: address, range: NSRange(address.startIndex..., in: address)) != nil }, address)
        }
        for address in ["https://example.com/doubleclick.net/script.js", "https://notdoubleclick.net/pixel", "https://doubleclick.net.example.com/ad", "https://accounts.google.com/login", "https://checkout.stripe.com/pay"] {
            let url = try XCTUnwrap(URL(string: address))
            XCTAssertFalse(ContentBlocker.blocks(url), address)
            XCTAssertFalse(filters.contains { $0.firstMatch(in: address, range: NSRange(address.startIndex..., in: address)) != nil }, address)
        }
    }

    func testCosmeticRulesHideAdsAndCanBeDisabledWithoutHidingLoginDialogs() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(try await ContentBlocker.rules())
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let html = "<html><body><div class='ad-banner' id='advert'>Ad</div><div role='dialog' id='login'>Sign in</div></body></html>"
        try await load(html, in: webView)
        let adDisplay = try await webView.evaluateJavaScript("getComputedStyle(document.getElementById('advert')).display") as? String
        let loginDisplay = try await webView.evaluateJavaScript("getComputedStyle(document.getElementById('login')).display") as? String
        XCTAssertEqual(adDisplay, "none")
        XCTAssertNotEqual(loginDisplay, "none")
        configuration.userContentController.removeAllContentRuleLists()
        try await load(html, in: webView)
        let unblockedDisplay = try await webView.evaluateJavaScript("getComputedStyle(document.getElementById('advert')).display") as? String
        XCTAssertNotEqual(unblockedDisplay, "none")
        webView.stopLoading()
    }

    private func load(_ html: String, in webView: WKWebView) async throws {
        webView.loadHTMLString(html, baseURL: URL(string: "https://example.com"))
        for _ in 0..<200 {
            try await Task.sleep(for: .milliseconds(50))
            if !webView.isLoading, webView.url != nil { return }
        }
        XCTFail("WebKit did not finish the fixture")
    }

    func testLinkPolicyKeepsWebAuthenticationInTheProfileAndRejectsUnsafeSchemes() throws {
        for address in ["https://accounts.google.com/login", "https://www.instagram.com/accounts/login/", "about:blank"] {
            let url = try XCTUnwrap(URL(string: address))
            XCTAssertEqual(WebNavigationPolicy.disposition(for: url), .web)
        }
        for address in ["mailto:hello@example.com", "tel:+1234", "sms:+1234", "maps://?q=London"] {
            let url = try XCTUnwrap(URL(string: address))
            XCTAssertEqual(WebNavigationPolicy.disposition(for: url), .external)
        }
        for address in ["javascript:alert(1)", "file:///etc/passwd", "data:text/html,hello", "instagram://user", "https://user:password@example.com/"] {
            let url = try XCTUnwrap(URL(string: address))
            XCTAssertEqual(WebNavigationPolicy.disposition(for: url), .blocked)
        }
    }
}
