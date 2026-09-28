import Foundation
import XCTest
@testable import lite

@MainActor
final class SavedContentGroupingTests: XCTestCase {
    func testGroupsByLocalCalendarDaysAcrossDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = try date("2026-03-09T00:30:00-07:00")
        let today = try bookmark("Today", at: "2026-03-09T00:10:00-07:00")
        let yesterday = try bookmark("Yesterday", at: "2026-03-08T00:10:00-08:00")
        let earlier = try bookmark("Earlier", at: "2026-03-07T23:50:00-08:00")
        let groups = SavedContentGroup.make([earlier, today, yesterday], sortOrder: .newest,
                                           date: { $0.createdAt }, title: { $0.title }, calendar: calendar, now: now)
        XCTAssertEqual(groups.map(\.id), ["today", "yesterday", "earlier"])
        XCTAssertEqual(groups.map { $0.items.map(\.id) }, [[today.id], [yesterday.id], [earlier.id]])
    }

    func testNewestSortPreservesChronologyWithinEachGroup() throws {
        let older = try bookmark("A", at: "2026-09-20T10:00:00Z")
        let newer = try bookmark("Z", at: "2026-09-20T11:00:00Z")
        let groups = SavedContentGroup.make([older, newer], sortOrder: .newest,
                                           date: { $0.createdAt }, title: { $0.title }, now: try date("2026-09-21T12:00:00Z"))
        XCTAssertEqual(groups.flatMap(\.items).map(\.id), [newer.id, older.id])
    }

    func testNameSortUsesNaturalOrderAcrossDatesAndOmitsEmptyGroups() throws {
        let ten = try bookmark("Guide 10", at: "2026-09-21T10:00:00Z")
        let two = try bookmark("Guide 2", at: "2026-09-10T10:00:00Z")
        let groups = SavedContentGroup.make([ten, two], sortOrder: .name,
                                           date: { $0.createdAt }, title: { $0.title })
        XCTAssertEqual(groups.map(\.id), ["name"])
        XCTAssertEqual(groups[0].items.map(\.id), [two.id, ten.id])
        let empty = SavedContentGroup<SavedBookmark>.make([], sortOrder: .newest,
                                                         date: { $0.createdAt }, title: { $0.title })
        XCTAssertTrue(empty.isEmpty)
    }

    private func date(_ string: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: string))
    }

    private func bookmark(_ title: String, at timestamp: String) throws -> SavedBookmark {
        SavedBookmark(id: UUID(), profileID: UUID(), title: title,
                      url: try XCTUnwrap(URL(string: "https://example.com")), createdAt: try date(timestamp))
    }
}
