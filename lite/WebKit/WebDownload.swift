import Foundation
import Observation
import WebKit

@Observable
@MainActor
final class WebDownload: Identifiable {
    // Avoid Swift 6.2.4 isolated-deinit back-deployment crash on iOS 26.2.
    nonisolated deinit {}

    let id = UUID()
    let download: WKDownload
    private(set) var filename = "Download"
    private(set) var progress = 0.0
    private(set) var isCancelling = false
    private(set) var errorMessage: String?
    var destinationURL: URL?

    @ObservationIgnored private var progressObservation: NSKeyValueObservation?
    @ObservationIgnored private let onProgress: (Double, Int64) -> Void

    init(download: WKDownload, onProgress: @escaping (Double, Int64) -> Void = { _, _ in }) {
        self.download = download
        self.onProgress = onProgress
        progressObservation = download.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            let byteCount = progress.completedUnitCount
            Task { @MainActor [weak self] in
                self?.progress = fraction
                self?.onProgress(fraction, byteCount)
            }
        }
    }

    func prepare(filename: String, profileID: UUID) throws -> URL {
        self.filename = SavedContentStore.sanitizedFilename(filename)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteDownloads", isDirectory: true)
            .appendingPathComponent(profileID.uuidString, isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        let safeName = self.filename
        let destination = root.appendingPathComponent(safeName, isDirectory: false)
        try? FileManager.default.removeItem(at: destination)
        destinationURL = destination
        return destination
    }

    static func removeTemporaryFiles(profileID: UUID) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteDownloads", isDirectory: true)
            .appendingPathComponent(profileID.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func cancel() {
        guard !isCancelling else { return }
        isCancelling = true
        let directory = destinationURL?.deletingLastPathComponent()
        download.cancel { [weak self] _ in
            // WebKit may still be writing until cancellation completes.
            if let directory { try? FileManager.default.removeItem(at: directory) }
            Task { @MainActor [weak self] in self?.isCancelling = false }
        }
    }

    func fail(_ error: Error) {
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
        errorMessage = "The download couldn’t finish. Check your connection and try again."
    }

    func cleanup() {
        guard let destinationURL else { return }
        try? FileManager.default.removeItem(at: destinationURL.deletingLastPathComponent())
        self.destinationURL = nil
    }
}
