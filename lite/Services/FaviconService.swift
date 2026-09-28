import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Network

/// Uses an independent executor and a cookie-free session, never a Lite App's login session.
actor FaviconService {
    /// A clean 128/180 px touch icon is preferable to an unrelated symbol.
    /// Resolution still contributes to ranking, so larger artwork wins.
    nonisolated static let minimumPixelSize = 128
    nonisolated static let preferredMinimumPixelSize = 192
    nonisolated static let maximumPixelSize = 512

    nonisolated private struct ProcessedIcon: Sendable {
        let data: Data
        let pixels: Int
        let visualScore: Int
    }

    nonisolated struct Download: Sendable {
        let data: Data
        let url: URL
    }

    nonisolated enum Resource: Sendable {
        case page, manifest, image
        var limit: Int { self == .manifest ? 262_144 : 1_048_576 }
        var accept: String {
            switch self {
            case .page: "text/html, application/xhtml+xml"
            case .manifest: "application/manifest+json, application/json"
            case .image: "image/png, image/x-icon, image/*;q=0.8"
            }
        }
        func accepts(_ mime: String) -> Bool {
            switch self {
            case .page: ["text/html", "application/xhtml+xml"].contains(mime)
            case .manifest: ["application/manifest+json", "application/json", "text/json"].contains(mime)
            case .image: mime.hasPrefix("image/") || mime == "application/octet-stream"
            }
        }
    }

    typealias Loader = @Sendable (URL, Resource, Date) async -> Download?
    private let loader: Loader

    init(loader: @escaping Loader = FaviconService.download) { self.loader = loader }

    init(proxyConfigurations: [ProxyConfiguration]) {
        loader = { url, resource, deadline in
            await Self.download(url, resource: resource, deadline: deadline, proxies: proxyConfigurations)
        }
    }

    func fetch(for url: URL) async -> Data? {
        guard !Task.isCancelled,
              let validated = try? WebsiteURL.normalized(url.absoluteString),
              var origin = URLComponents(url: validated, resolvingAgainstBaseURL: false) else { return nil }
        // Fetch only public origin metadata, never a user's private path/query.
        origin.path = "/"
        origin.query = nil
        origin.fragment = nil
        guard let pageURL = origin.url else { return nil }
        let deadline = Date().addingTimeInterval(18)
        var candidates: [FaviconDiscovery.Candidate] = []
        var effectivePageURL = pageURL
        if let page = await loader(pageURL, .page, deadline), !Task.isCancelled {
            effectivePageURL = page.url
            let discovered = FaviconDiscovery.html(page.data, at: page.url)
            candidates += discovered.icons
            if let manifestURL = discovered.manifest,
               let manifest = await loader(manifestURL, .manifest, deadline), !Task.isCancelled {
                candidates += FaviconDiscovery.manifest(manifest.data, at: manifest.url)
            }
        }
        // Root files get reserved request slots. Otherwise eight stale, falsely
        // declared metadata entries could crowd out the only working icon.
        let fallbackLocations: [(String, FaviconDiscovery.Source)] = [
            ("/apple-touch-icon.png", .rootAppleTouchIcon),
            ("/apple-touch-icon-precomposed.png", .rootAppleTouchIcon),
            ("/favicon.ico", .rootFavicon)
        ]
        let rootCandidates: [FaviconDiscovery.Candidate] = fallbackLocations.compactMap { item in
            let (path, source) = item
            guard let fallbackURL = URL(string: path, relativeTo: effectivePageURL)?.absoluteURL else { return nil }
            return .init(url: fallbackURL, declaredSize: 0, source: source)
        }
        guard !Task.isCancelled, Date() < deadline else { return nil }
        let ranked = FaviconDiscovery.ranked(candidates)
        var seen = Set(ranked.map(\.url))
        let requested = ranked + rootCandidates.filter { seen.insert($0.url).inserted }
        let loader = self.loader
        return await withTaskGroup(of: (Int, Data, Int)?.self) { group in
            for (index, candidate) in requested.enumerated() {
                group.addTask {
                    guard !Task.isCancelled,
                          let download = await loader(candidate.url, .image, deadline),
                          !Task.isCancelled,
                          let processed = Self.processedIcon(from: download.data) else { return nil }
                    let preferredBonus = processed.pixels >= Self.preferredMinimumPixelSize ? 60 : 0
                    let score = processed.pixels + processed.visualScore + preferredBonus + candidate.source.qualityBonus
                    return (index, processed.data, score)
                }
            }
            var best: (index: Int, data: Data, score: Int)?
            for await result in group {
                guard let (index, data, score) = result else { continue }
                if score > (best?.score ?? Int.min) || (score == best?.score && index < (best?.index ?? Int.max)) {
                    best = (index, data, score)
                }
            }
            return Task.isCancelled ? nil : best?.data
        }
    }

    nonisolated private static func download(_ url: URL, resource: Resource, deadline: Date) async -> Download? {
        await download(url, resource: resource, deadline: deadline, proxies: [])
    }

    nonisolated private static func download(_ url: URL, resource: Resource, deadline: Date, proxies: [ProxyConfiguration]) async -> Download? {
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0, !Task.isCancelled else { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.proxyConfigurations = proxies
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = min(5, remaining)
        configuration.timeoutIntervalForResource = min(6, remaining)
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue(resource.accept, forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpShouldHandleCookies = false
        do {
            let redirects = FaviconRedirectPolicy(origin: url)
            let (bytes, response) = try await session.bytes(for: request, delegate: redirects)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  response.expectedContentLength <= resource.limit,
                  resource.accepts(response.mimeType?.lowercased() ?? "") else { return nil }
            var data = Data()
            data.reserveCapacity(min(max(Int(response.expectedContentLength), 0), resource.limit))
            for try await byte in bytes {
                guard data.count < resource.limit, !Task.isCancelled, Date() < deadline else { return nil }
                data.append(byte)
            }
            return data.isEmpty ? nil : Download(data: data, url: response.url ?? url)
        } catch {
            return nil
        }
    }

    nonisolated static func pixelSize(of data: Data) -> Int {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return 0 }
        return min(width, height)
    }

    /// Rejects malformed, blank or excessive images and stores a normalized square PNG.
    nonisolated static func sanitizedIconData(from data: Data) -> Data? {
        processedIcon(from: data)?.data
    }

    /// Used by renderers to keep corrupt legacy data from suppressing a fallback.
    nonisolated static func isVisuallyUsableIconData(_ data: Data) -> Bool {
        guard data.count <= 4_194_304,
              let source = CGImageSourceCreateWithData(data as CFData, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else { return false }
        var selected: (index: Int, area: Int)?
        for index in 0..<min(CGImageSourceGetCount(source), 32) {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width >= minimumPixelSize, height >= minimumPixelSize,
                  width <= 16_384, height <= 16_384,
                  max(width, height) <= min(width, height) * 2,
                  width * height <= 64_000_000 else { continue }
            if width * height > (selected?.area ?? 0) { selected = (index, width * height) }
        }
        guard let selected,
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, selected.index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let metrics = visualMetrics(of: thumbnail) else { return false }
        return metrics.isUsable
    }

    nonisolated private static func processedIcon(from data: Data) -> ProcessedIcon? {
        guard data.count <= 1_048_576,
              let source = CGImageSourceCreateWithData(data as CFData, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else { return nil }

        // ICO files commonly list a tiny toolbar image before larger app icons.
        // Read bounded metadata first; decode only the largest safe representation.
        var selected: (index: Int, width: Int, height: Int)?
        for index in 0..<min(CGImageSourceGetCount(source), 32) {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width >= minimumPixelSize, height >= minimumPixelSize,
                  width <= 16_384, height <= 16_384,
                  max(width, height) <= min(width, height) * 2,
                  width * height <= 64_000_000 else { continue }
            let selectedArea = selected.map { $0.width * $0.height } ?? 0
            if width * height > selectedArea {
                selected = (index, width, height)
            }
        }
        guard let selected else { return nil }
        // Low-resolution source art stays low-resolution; resizing cannot add detail.
        let maximumPixelSize = min(Self.maximumPixelSize, max(selected.width, selected.height))
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, selected.index, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary),
              let metrics = visualMetrics(of: thumbnail), metrics.isUsable,
              let normalized = normalizedSquare(from: thumbnail) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, normalized, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return ProcessedIcon(
            data: output as Data,
            pixels: min(min(selected.width, selected.height), maximumPixelSize),
            visualScore: metrics.score
        )
    }

    nonisolated private struct VisualMetrics {
        let alphaCoverage: Double
        let boundsWidth: Double
        let boundsHeight: Double
        let variance: Double

        var isUsable: Bool {
            guard alphaCoverage >= 0.01, boundsWidth >= 0.1, boundsHeight >= 0.1 else { return false }
            // Transparency can describe a meaningful single-color glyph. Fully
            // opaque artwork needs visible tonal variation to avoid accepting a
            // blank white/black/solid-color square.
            return alphaCoverage < 0.95 || variance >= 0.0008
        }

        var score: Int {
            let coverageScore = min(20, Int(alphaCoverage * 20))
            let detailScore = min(30, Int(sqrt(max(variance, 0)) * 180))
            return coverageScore + detailScore
        }
    }

    nonisolated private static func visualMetrics(of image: CGImage) -> VisualMetrics? {
        let side = 64
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let address = buffer.baseAddress,
                  let context = CGContext(
                    data: address,
                    width: side,
                    height: side,
                    bitsPerComponent: 8,
                    bytesPerRow: side * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.interpolationQuality = .high
            context.clear(CGRect(x: 0, y: 0, width: side, height: side))
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { return nil }

        var visibleCount = 0
        var minX = side, minY = side, maxX = -1, maxY = -1
        var luminanceSum = 0.0, luminanceSquaredSum = 0.0
        var alphaSum = 0.0, alphaSquaredSum = 0.0
        for y in 0..<side {
            for x in 0..<side {
                let offset = (y * side + x) * 4
                let alpha = Double(pixels[offset + 3]) / 255
                alphaSum += alpha
                alphaSquaredSum += alpha * alpha
                guard alpha >= 0.04 else { continue }
                visibleCount += 1
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
                let inverseAlpha = 1 / alpha
                let red = min(1, Double(pixels[offset]) / 255 * inverseAlpha)
                let green = min(1, Double(pixels[offset + 1]) / 255 * inverseAlpha)
                let blue = min(1, Double(pixels[offset + 2]) / 255 * inverseAlpha)
                let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
                luminanceSum += luminance
                luminanceSquaredSum += luminance * luminance
            }
        }
        guard visibleCount > 0 else { return nil }
        let count = Double(visibleCount)
        let total = Double(side * side)
        let luminanceVariance = max(0, luminanceSquaredSum / count - pow(luminanceSum / count, 2))
        let alphaVariance = max(0, alphaSquaredSum / total - pow(alphaSum / total, 2))
        return VisualMetrics(
            alphaCoverage: count / total,
            boundsWidth: Double(maxX - minX + 1) / Double(side),
            boundsHeight: Double(maxY - minY + 1) / Double(side),
            variance: luminanceVariance + alphaVariance
        )
    }

    nonisolated private static func normalizedSquare(from image: CGImage) -> CGImage? {
        let side = min(max(image.width, image.height), maximumPixelSize)
        guard side > 0,
              let context = CGContext(
                data: nil,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: side, height: side))
        context.interpolationQuality = .high
        let scale = min(CGFloat(side) / CGFloat(image.width), CGFloat(side) / CGFloat(image.height))
        let width = CGFloat(image.width) * scale
        let height = CGFloat(image.height) * scale
        context.draw(image, in: CGRect(
            x: (CGFloat(side) - width) / 2,
            y: (CGFloat(side) - height) / 2,
            width: width,
            height: height
        ))
        return context.makeImage()
    }
}

/// Redirect callbacks are serialized by URLSession's delegate queue. The lock also
/// makes the policy safe if Foundation changes which queue invokes a callback.
nonisolated private final class FaviconRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let origin: URL
    private let lock = NSLock()
    private var redirectCount = 0

    init(origin: URL) {
        self.origin = origin
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        lock.lock()
        redirectCount += 1
        let isWithinLimit = redirectCount <= 3
        lock.unlock()

        guard isWithinLimit, let target = request.url,
              target.scheme?.lowercased() == "https",
              FaviconDiscovery.sameSiteHost(target.host, origin.host),
              (target.port ?? 443) == (origin.port ?? 443),
              target.user == nil, target.password == nil else {
            completionHandler(nil)
            return
        }
        var safeRequest = request
        safeRequest.httpShouldHandleCookies = false
        completionHandler(safeRequest)
    }
}
