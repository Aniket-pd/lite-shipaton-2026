import Foundation
import XCTest
@testable import lite

@MainActor
final class WebsiteURLTests: XCTestCase {
    func testBareHostDefaultsToHTTPSAndPreservesPathAndQuery() throws {
        let result = try WebsiteURL.normalized("  example.com/account?view=work  ")
        XCTAssertEqual(result.scheme, "https")
        XCTAssertEqual(result.host, "example.com")
        XCTAssertEqual(result.path, "/account")
        XCTAssertEqual(result.query, "view=work")
    }

    func testRejectsExecutableAndLocalResourceSchemes() {
        for value in [
            "javascript:alert(1)", "data:text/html,hello", "file:///private/test.html",
            "about:blank", "mailto:hello@example.com", "tel:+1234", ""
        ] {
            XCTAssertThrowsError(try WebsiteURL.normalized(value), "Accepted unsafe URL: \(value)")
        }
    }

    func testRejectsEmbeddedCredentialsAndMissingHost() {
        for value in ["https://user:password@example.com", "https://", "https:///", "https://exa mple.com"] {
            XCTAssertThrowsError(try WebsiteURL.normalized(value), "Accepted invalid URL: \(value)")
        }
    }
}
