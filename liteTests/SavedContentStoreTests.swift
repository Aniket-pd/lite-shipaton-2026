import Foundation
import XCTest
@testable import lite

@MainActor
final class SavedContentStoreTests: XCTestCase {
    private var root: URL!
    private var store: SavedContentStore!

    private func prepareStore() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SavedContentTests-\(UUID())", isDirectory: true)
        store = SavedContentStore(rootURL: root)
    }

    func testBookmarksPersistAndDeduplicateOnlyWithinTheirProfile() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let firstProfile = UUID(), secondProfile = UUID()
        let url = URL(string: "https://example.com/account")!
        let first = try store.addBookmark(profileID: firstProfile, title: "Work", url: url)
        let duplicate = try store.addBookmark(profileID: firstProfile, title: "Again", url: url)
        let second = try store.addBookmark(profileID: secondProfile, title: "Personal", url: url)
        XCTAssertEqual(first.id, duplicate.id)
        XCTAssertNotEqual(first.id, second.id)
        let reloaded = SavedContentStore(rootURL: root)
        XCTAssertEqual(reloaded.bookmarks(for: firstProfile), [first])
        XCTAssertEqual(reloaded.bookmarks(for: secondProfile), [second])
        try reloaded.deleteBookmark(first)
        XCTAssertTrue(SavedContentStore(rootURL: root).bookmarks(for: firstProfile).isEmpty)
        XCTAssertEqual(reloaded.bookmarks(for: secondProfile), [second])
    }

    func testSavedContentPresenceTracksBookmarksAndDownloads() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let emptyProfile = UUID(), bookmarkedProfile = UUID(), downloadedProfile = UUID()

        XCTAssertFalse(store.hasSavedContent(for: emptyProfile))
        try store.addBookmark(profileID: bookmarkedProfile, title: "Saved", url: URL(string: "https://example.com")!)
        XCTAssertTrue(store.hasSavedContent(for: bookmarkedProfile))
        let file = try completeDownload(profileID: downloadedProfile, filename: "saved.txt")
        XCTAssertTrue(store.hasSavedContent(for: downloadedProfile))

        try store.deleteBookmark(try XCTUnwrap(store.bookmarks(for: bookmarkedProfile).first))
        try store.deleteDownload(file)
        XCTAssertFalse(store.hasSavedContent(for: bookmarkedProfile))
        XCTAssertFalse(store.hasSavedContent(for: downloadedProfile))
    }

    func testOnlyWebURLsWithoutEmbeddedCredentialsCanBeBookmarked() {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        for address in ["javascript:alert(1)", "file:///etc/passwd", "blob:https://example.com/123", "https://user:secret@example.com", "https:///", "mailto:user@example.com"] {
            guard let url = URL(string: address) else { continue }
            XCTAssertThrowsError(try store.addBookmark(profileID: UUID(), title: "Unsafe", url: url), address)
        }
    }

    func testDownloadSurvivesRestartAndDeletionRemovesItsFile() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID()
        let record = try completeDownload(profileID: profile, filename: "Receipt.pdf", data: Data("fixture".utf8))
        let reopened = SavedContentStore(rootURL: root)
        let restored = try XCTUnwrap(reopened.downloads(for: profile).first)
        XCTAssertEqual(restored.id, record.id)
        XCTAssertEqual(restored.status, .completed)
        XCTAssertEqual(restored.byteCount, 7)
        XCTAssertEqual(restored.progress, 1)
        let savedURL = try reopened.fileURL(for: restored)
        XCTAssertEqual(try Data(contentsOf: savedURL), Data("fixture".utf8))
        try reopened.deleteDownload(restored)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertTrue(SavedContentStore(rootURL: root).downloads(for: profile).isEmpty)
    }

    func testProfileDeletionDoesNotTouchAnotherProfilesContent() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID(), other = UUID()
        let file = try completeDownload(profileID: profile, filename: "same.txt")
        let otherFile = try completeDownload(profileID: other, filename: "same.txt")
        try store.addBookmark(profileID: profile, title: "Page", url: URL(string: "https://example.com")!)
        let removedURL = try store.fileURL(for: file)
        let retainedURL = try store.fileURL(for: otherFile)
        try store.removeProfile(profile)
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: retainedURL.path))
        XCTAssertTrue(store.bookmarks(for: profile).isEmpty)
        XCTAssertTrue(store.downloads(for: profile).isEmpty)
        XCTAssertEqual(store.downloads(for: other).map(\.id), [otherFile.id])
        try store.removeProfile(profile) // Receipt retries are safe.
    }

    func testMaliciousFilenamesCannotEscapeTheDownloadDirectory() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID()
        for filename in ["../../private.txt", "..\\..\\secret.txt", "/absolute.txt", "..", "\u{0}\n", "report:2026.pdf"] {
            let saved = try completeDownload(profileID: profile, filename: filename)
            let url = try store.fileURL(for: saved)
            XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, saved.id.uuidString)
            XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, profile.uuidString)
            XCTAssertFalse(saved.filename.contains("/"))
            XCTAssertFalse(saved.filename.contains("\\"))
            XCTAssertFalse(saved.filename.contains(":"))
            XCTAssertFalse(saved.filename.isEmpty)
            XCTAssertNotEqual(saved.filename, "..")
        }
    }

    func testRestartMarksUnfinishedDownloadsFailedWithoutPersistingEveryProgressTick() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID(), id = UUID()
        try store.beginDownload(id: id, profileID: profile, filename: "unfinished.txt", sourceURL: nil)
        let metadata = manifestURL(profile)
        let beforeProgress = try Data(contentsOf: metadata)
        store.updateDownload(id: id, profileID: profile, progress: 0.4, byteCount: 12)
        XCTAssertEqual(store.downloads(for: profile).first?.progress, 0.4)
        XCTAssertEqual(try Data(contentsOf: metadata), beforeProgress)
        XCTAssertThrowsError(try store.deleteDownload(try XCTUnwrap(store.downloads(for: profile).first)))
        let reopened = SavedContentStore(rootURL: root)
        let interrupted = try XCTUnwrap(reopened.downloads(for: profile).first)
        XCTAssertEqual(interrupted.status, .failed)
        XCTAssertNotNil(interrupted.errorMessage)
        XCTAssertEqual(SavedContentStore(rootURL: root).downloads(for: profile).first?.status, .failed)
    }

    func testFailedFinishDoesNotDeclareCompletionAndReturnsFileToStaging() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID(), id = UUID()
        try store.beginDownload(id: id, profileID: profile, filename: "report.txt", sourceURL: nil)
        let metadata = manifestURL(profile)
        let oldMetadata = try Data(contentsOf: metadata)
        try FileManager.default.removeItem(at: metadata)
        try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
        let temporary = root.appendingPathComponent("staging-\(UUID()).txt")
        try Data("keep me".utf8).write(to: temporary)
        XCTAssertThrowsError(try store.finishDownload(id: id, profileID: profile, temporaryURL: temporary))
        XCTAssertEqual(store.downloads(for: profile).first?.status, .downloading)
        XCTAssertEqual(try String(contentsOf: temporary, encoding: .utf8), "keep me")
        try FileManager.default.removeItem(at: metadata)
        try oldMetadata.write(to: metadata)
        try store.failDownload(id: id, profileID: profile, message: "Couldn’t save")
        XCTAssertEqual(SavedContentStore(rootURL: root).downloads(for: profile).first?.status, .failed)
    }

    func testCorruptedManifestIsPreservedAndCanBeRetriedAfterRepair() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID()
        let bookmark = try store.addBookmark(profileID: profile, title: "Existing", url: URL(string: "https://example.com")!)
        let metadata = manifestURL(profile)
        let original = try Data(contentsOf: metadata)
        let corrupt = Data("invalid metadata".utf8)
        try corrupt.write(to: metadata)
        let reopened = SavedContentStore(rootURL: root)
        XCTAssertTrue(reopened.bookmarks(for: profile).isEmpty)
        XCTAssertNotNil(reopened.loadError(for: profile))
        XCTAssertThrowsError(try reopened.addBookmark(profileID: profile, title: "New", url: URL(string: "https://example.org")!))
        XCTAssertEqual(try Data(contentsOf: metadata), corrupt)
        try original.write(to: metadata)
        reopened.retryLoad(for: profile)
        XCTAssertNil(reopened.loadError(for: profile))
        XCTAssertEqual(reopened.bookmarks(for: profile), [bookmark])
    }

    func testSymlinksCannotReadOrDeleteAnotherProfile() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID(), other = UUID()
        let bookmark = try store.addBookmark(profileID: other, title: "Private", url: URL(string: "https://example.com")!)
        let link = root.appendingPathComponent(profile.uuidString)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent(other.uuidString))
        let reopened = SavedContentStore(rootURL: root)
        XCTAssertTrue(reopened.bookmarks(for: profile).isEmpty)
        XCTAssertNotNil(reopened.loadError(for: profile))
        XCTAssertThrowsError(try reopened.removeProfile(profile))
        XCTAssertEqual(reopened.bookmarks(for: other), [bookmark])
    }

    func testFailedWritesDoNotMutateVisibleBookmarks() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID()
        let first = try store.addBookmark(profileID: profile, title: "Existing", url: URL(string: "https://example.com")!)
        let metadata = manifestURL(profile)
        try FileManager.default.removeItem(at: metadata)
        try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.addBookmark(profileID: profile, title: "New", url: URL(string: "https://example.org")!))
        XCTAssertEqual(store.bookmarks(for: profile), [first])
        XCTAssertThrowsError(try store.deleteBookmark(first))
        XCTAssertEqual(store.bookmarks(for: profile), [first])
    }

    func testMissingFilesCannotBeOpenedAsCompletedDownloads() throws {
        prepareStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = UUID()
        let file = try completeDownload(profileID: profile, filename: "missing.txt")
        try FileManager.default.removeItem(at: store.fileURL(for: file))
        XCTAssertThrowsError(try store.fileURL(for: file))
        try store.deleteDownload(file)
        XCTAssertTrue(store.downloads(for: profile).isEmpty)
    }

    private func manifestURL(_ profileID: UUID) -> URL {
        root.appendingPathComponent(profileID.uuidString).appendingPathComponent("manifest.json")
    }

    private func completeDownload(profileID: UUID, filename: String, data: Data = Data("fixture".utf8)) throws -> SavedFile {
        let id = UUID()
        try store.beginDownload(id: id, profileID: profileID, filename: filename, sourceURL: URL(string: "https://example.com/file")!)
        let temporary = root.appendingPathComponent("staging-\(UUID()).txt")
        try data.write(to: temporary)
        try store.finishDownload(id: id, profileID: profileID, temporaryURL: temporary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.path))
        return try XCTUnwrap(store.downloads(for: profileID).first(where: { $0.id == id }))
    }
}
