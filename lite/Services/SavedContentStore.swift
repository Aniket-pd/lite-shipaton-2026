import Foundation
import Observation

struct SavedBookmark: Codable, Identifiable, Equatable {
    let id: UUID
    let profileID: UUID
    var title: String
    let url: URL
    let createdAt: Date
}

enum SavedDownloadStatus: String, Codable {
    case downloading, completed, failed
}

struct SavedFile: Codable, Identifiable, Equatable {
    let id: UUID
    let profileID: UUID
    let filename: String
    let sourceURL: URL?
    let createdAt: Date
    var byteCount: Int64
    var status: SavedDownloadStatus
    var progress: Double
    var errorMessage: String?
}

/// Private, device-local content keyed by the same identity as the WebKit profile.
/// Authentication controls access in the UI; iOS file protection also protects data at rest.
@Observable
@MainActor
final class SavedContentStore {
    // Avoid Swift 6.2.4 isolated-deinit back-deployment crash on iOS 26.2.
    nonisolated deinit {}

    static let shared: SavedContentStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("LiteSavedUITests", isDirectory: true)
            return SavedContentStore(rootURL: root)
        }
        #endif
        return SavedContentStore()
    }()

    private struct Manifest: Codable {
        var version = 1
        var bookmarks: [SavedBookmark] = []
        var downloads: [SavedFile] = []
    }

    enum StoreError: LocalizedError {
        case unavailable, invalidURL, invalidMetadata, missingDownload, missingFile, activeDownload

        var errorDescription: String? {
            switch self {
            case .unavailable: "Saved content couldn’t be loaded. Your existing files have not been changed."
            case .invalidURL: "Only website pages can be bookmarked."
            case .invalidMetadata: "Saved content couldn’t be read. Your existing files have not been changed."
            case .missingDownload: "This download is no longer available."
            case .missingFile: "The downloaded file is no longer available. Download it again from the website."
            case .activeDownload: "Cancel this download in its container before deleting it."
            }
        }
    }

    private var manifests: [UUID: Manifest] = [:]
    private var loadErrors: [UUID: String] = [:]
    @ObservationIgnored private var loadedProfiles: Set<UUID> = []
    @ObservationIgnored private let rootURL: URL
    @ObservationIgnored private let fileManager: FileManager

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.rootURL = rootURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiteSaved", isDirectory: true)
        self.fileManager = fileManager
    }

    func bookmarks(for profileID: UUID) -> [SavedBookmark] {
        load(profileID)
        return manifests[profileID]?.bookmarks.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    func downloads(for profileID: UUID) -> [SavedFile] {
        load(profileID)
        return manifests[profileID]?.downloads.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    func loadError(for profileID: UUID) -> String? {
        load(profileID)
        return loadErrors[profileID]
    }

    func hasSavedContent(for profileID: UUID) -> Bool {
        load(profileID)
        guard loadErrors[profileID] == nil, let manifest = manifests[profileID] else { return false }
        return !manifest.bookmarks.isEmpty || !manifest.downloads.isEmpty
    }

    /// Retry transient file-protection or storage errors when the app becomes active.
    func retryLoad(for profileID: UUID) {
        guard loadErrors[profileID] != nil else { return }
        loadErrors.removeValue(forKey: profileID)
        loadedProfiles.remove(profileID)
        load(profileID)
    }

    @discardableResult
    func addBookmark(profileID: UUID, title: String, url: URL) throws -> SavedBookmark {
        guard Self.isBookmarkURL(url) else { throw StoreError.invalidURL }
        var manifest = try content(for: profileID)
        if let existing = manifest.bookmarks.first(where: { $0.url == url }) { return existing }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let bookmark = SavedBookmark(id: UUID(), profileID: profileID,
            title: trimmedTitle.isEmpty ? (url.host ?? "Saved Page") : trimmedTitle,
            url: url, createdAt: .now)
        manifest.bookmarks.append(bookmark)
        try save(manifest, for: profileID)
        return bookmark
    }

    func deleteBookmark(_ bookmark: SavedBookmark) throws {
        var manifest = try content(for: bookmark.profileID)
        manifest.bookmarks.removeAll { $0.id == bookmark.id }
        try save(manifest, for: bookmark.profileID)
    }

    func deleteDownload(_ download: SavedFile) throws {
        var manifest = try content(for: download.profileID)
        guard let stored = manifest.downloads.first(where: { $0.id == download.id }) else { return }
        guard stored.status != .downloading else { throw StoreError.activeDownload }
        let directory = try downloadDirectory(id: stored.id, profileID: stored.profileID)
        // Keep the record until removal succeeds, so filesystem failures remain
        // visible and retryable. If metadata then fails, retry removes the record.
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        manifest.downloads.removeAll { $0.id == stored.id }
        try save(manifest, for: stored.profileID)
    }

    func fileURL(for download: SavedFile) throws -> URL {
        let manifest = try content(for: download.profileID)
        guard let stored = manifest.downloads.first(where: { $0.id == download.id }),
              stored.status == .completed else { throw StoreError.missingFile }
        let directory = try downloadDirectory(id: stored.id, profileID: stored.profileID)
        let url = try containedURL(directory.appendingPathComponent(stored.filename))
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw StoreError.missingFile }
        return url
    }

    func removeProfile(_ profileID: UUID) throws {
        let directory = try profileDirectory(profileID)
        if fileManager.fileExists(atPath: directory.path) { try fileManager.removeItem(at: directory) }
        manifests.removeValue(forKey: profileID)
        loadErrors.removeValue(forKey: profileID)
        loadedProfiles.remove(profileID)
    }

    @discardableResult
    func beginDownload(id: UUID, profileID: UUID, filename: String, sourceURL: URL?) throws -> SavedFile {
        var manifest = try content(for: profileID)
        guard !manifest.downloads.contains(where: { $0.id == id }) else { throw StoreError.invalidMetadata }
        let download = SavedFile(id: id, profileID: profileID, filename: Self.sanitizedFilename(filename),
            sourceURL: sourceURL, createdAt: .now, byteCount: 0, status: .downloading, progress: 0)
        manifest.downloads.append(download)
        try save(manifest, for: profileID)
        return download
    }

    /// Progress stays in memory. Start, finish, and failure are durable checkpoints.
    func updateDownload(id: UUID, profileID: UUID, progress: Double, byteCount: Int64) {
        guard var manifest = manifests[profileID],
              let index = manifest.downloads.firstIndex(where: { $0.id == id && $0.status == .downloading }) else { return }
        manifest.downloads[index].progress = progress.isFinite ? min(1, max(0, progress)) : 0
        manifest.downloads[index].byteCount = max(0, byteCount)
        manifests[profileID] = manifest
    }

    func finishDownload(id: UUID, profileID: UUID, temporaryURL: URL) throws {
        var manifest = try content(for: profileID)
        guard let index = manifest.downloads.firstIndex(where: { $0.id == id && $0.status == .downloading }) else {
            throw StoreError.missingDownload
        }
        let values = try temporaryURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw StoreError.missingFile }
        let directory = try downloadDirectory(id: id, profileID: profileID)
        try createProtectedDirectory(directory)
        let destination = try containedURL(directory.appendingPathComponent(manifest.downloads[index].filename))
        // Both locations are in the app sandbox, so this is a same-volume rename,
        // avoiding a large file copy on the main actor. Roll back if metadata fails.
        var moved = false
        do {
            try fileManager.moveItem(at: temporaryURL, to: destination)
            moved = true
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
            manifest.downloads[index].status = .completed
            manifest.downloads[index].progress = 1
            manifest.downloads[index].byteCount = Int64(values.fileSize ?? 0)
            manifest.downloads[index].errorMessage = nil
            try save(manifest, for: profileID)
        } catch {
            if moved { try? fileManager.moveItem(at: destination, to: temporaryURL) }
            if !fileManager.fileExists(atPath: destination.path) { try? fileManager.removeItem(at: directory) }
            throw error
        }
    }

    func failDownload(id: UUID, profileID: UUID, message: String) throws {
        var manifest = try content(for: profileID)
        guard let index = manifest.downloads.firstIndex(where: { $0.id == id && $0.status == .downloading }) else { return }
        manifest.downloads[index].status = .failed
        manifest.downloads[index].errorMessage = message
        try save(manifest, for: profileID)
    }

    static func isBookmarkURL(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
            && url.host?.isEmpty == false && url.user == nil && url.password == nil
    }

    static func sanitizedFilename(_ value: String) -> String {
        let component = value.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? ""
        let cleaned = component.replacingOccurrences(of: ":", with: "-")
            .components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != ".", cleaned != ".." else { return "Download" }
        var result = ""
        for character in cleaned {
            guard result.utf8.count + String(character).utf8.count <= 220 else { break }
            result.append(character)
        }
        return result.isEmpty ? "Download" : result
    }

    private func load(_ profileID: UUID) {
        guard loadedProfiles.insert(profileID).inserted else { return }
        do {
            let url = try metadataURL(profileID)
            let data: Data
            do { data = try Data(contentsOf: url) }
            catch {
                let readError = error as NSError
                guard readError.domain == NSCocoaErrorDomain, readError.code == NSFileReadNoSuchFileError else { throw error }
                manifests[profileID] = Manifest()
                return
            }
            var manifest = try JSONDecoder().decode(Manifest.self, from: data)
            guard manifest.version == 1,
                  Set(manifest.bookmarks.map(\.id)).count == manifest.bookmarks.count,
                  Set(manifest.downloads.map(\.id)).count == manifest.downloads.count,
                  manifest.bookmarks.allSatisfy({ $0.profileID == profileID && Self.isBookmarkURL($0.url) }),
                  manifest.downloads.allSatisfy({ $0.profileID == profileID && $0.filename == Self.sanitizedFilename($0.filename) }) else {
                throw StoreError.invalidMetadata
            }
            var interrupted = false
            for index in manifest.downloads.indices where manifest.downloads[index].status == .downloading {
                manifest.downloads[index].status = .failed
                manifest.downloads[index].errorMessage = "The download was interrupted. Download it again from the website."
                interrupted = true
            }
            if interrupted { try write(manifest, for: profileID) }
            manifests[profileID] = manifest
        } catch {
            // Never treat an unreadable manifest as an empty one and overwrite it.
            loadErrors[profileID] = StoreError.unavailable.localizedDescription
        }
    }

    private func content(for profileID: UUID) throws -> Manifest {
        load(profileID)
        guard loadErrors[profileID] == nil, let manifest = manifests[profileID] else { throw StoreError.unavailable }
        return manifest
    }

    private func save(_ manifest: Manifest, for profileID: UUID) throws {
        try write(manifest, for: profileID)
        manifests[profileID] = manifest
    }

    private func write(_ manifest: Manifest, for profileID: UUID) throws {
        try createProtectedDirectory(rootURL)
        try createProtectedDirectory(try profileDirectory(profileID))
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: metadataURL(profileID), options: [.atomic, .completeFileProtection])
    }

    private func createProtectedDirectory(_ directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    }

    private func profileDirectory(_ profileID: UUID) throws -> URL {
        try containedURL(rootURL.appendingPathComponent(profileID.uuidString, isDirectory: true))
    }

    private func metadataURL(_ profileID: UUID) throws -> URL {
        try containedURL(profileDirectory(profileID).appendingPathComponent("manifest.json"))
    }

    private func downloadDirectory(id: UUID, profileID: UUID) throws -> URL {
        try containedURL(profileDirectory(profileID).appendingPathComponent(id.uuidString, isDirectory: true))
    }

    private func containedURL(_ url: URL) throws -> URL {
        let lexicalRoot = rootURL.standardizedFileURL.path
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
        let lexicalCandidate = url.standardizedFileURL.path
        let prefix = lexicalCandidate.hasPrefix(lexicalRoot + "/") ? lexicalRoot : root
        guard lexicalCandidate.hasPrefix(prefix + "/") else { throw StoreError.invalidMetadata }
        let suffix = lexicalCandidate.dropFirst(prefix.count)
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath()
        // Even a symlink to another profile inside LiteSaved must be rejected.
        guard candidate.path == root + suffix else { throw StoreError.invalidMetadata }
        return candidate
    }
}
