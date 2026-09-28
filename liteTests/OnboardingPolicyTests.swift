import XCTest
@testable import lite

final class OnboardingPolicyTests: XCTestCase {
    func testFreshInstallShowsIntroAndReturningInstallDoesNot() {
        XCTAssertTrue(OnboardingPolicy.shouldPresent(completed: false, previouslyUsed: false, isUITesting: false, requestedByTest: false))
        XCTAssertFalse(OnboardingPolicy.shouldPresent(completed: false, previouslyUsed: true, isUITesting: false, requestedByTest: false))
        XCTAssertFalse(OnboardingPolicy.shouldPresent(completed: true, previouslyUsed: false, isUITesting: false, requestedByTest: false))
    }

    func testExistingUITestsBypassIntroAndCompletionWinsOverOptIn() {
        XCTAssertFalse(OnboardingPolicy.shouldPresent(completed: false, previouslyUsed: false, isUITesting: true, requestedByTest: false))
        XCTAssertTrue(OnboardingPolicy.shouldPresent(completed: false, previouslyUsed: true, isUITesting: true, requestedByTest: true))
        XCTAssertFalse(OnboardingPolicy.shouldPresent(completed: true, previouslyUsed: false, isUITesting: true, requestedByTest: true))
    }
}
