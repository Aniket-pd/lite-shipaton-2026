import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import lite

@MainActor
final class FaviconServiceTests: XCTestCase {
    func testSelectsLargestRepresentationInMultiresolutionICO() throws {
        let small = try png(width: 16, height: 16)
        let large = try png(width: 256, height: 256)
        let input = iconContainer(images: [(16, small), (256, large)])
        let source = try XCTUnwrap(CGImageSourceCreateWithData(input as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 2, "Fixture must contain two ICO representations")

        let result = try XCTUnwrap(FaviconService.sanitizedIconData(from: input))
        let size = try dimensions(of: result)
        XCTAssertEqual(size.width, 256)
        XCTAssertEqual(size.height, 256)
    }

    func testDownsamplesLargeImageAndNormalizesSquareCanvas() throws {
        let input = try png(width: 640, height: 320)
        let result = try XCTUnwrap(FaviconService.sanitizedIconData(from: input))
        let size = try dimensions(of: result)
        XCTAssertEqual(size.width, 512)
        XCTAssertEqual(size.height, 512)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(result as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.png.identifier)
    }

    func testUsesCleanTouchIconsButRejectsTinyAndVeryWideSources() throws {
        for (width, height) in [(16, 16), (127, 127), (512, 64), (2048, 192)] {
            XCTAssertNil(FaviconService.sanitizedIconData(from: try png(width: width, height: height)))
        }
        for size in [128, 180, 192] {
            XCTAssertNotNil(FaviconService.sanitizedIconData(from: try png(width: size, height: size)))
        }
    }

    func testRejectsTransparentAndSolidBlankArtwork() throws {
        XCTAssertNil(FaviconService.sanitizedIconData(from: try png(
            width: 512, height: 512, backgroundAlpha: 0, drawsMark: false
        )))
        XCTAssertNil(FaviconService.sanitizedIconData(from: try png(
            width: 512, height: 512, backgroundAlpha: 1, drawsMark: false
        )))
        XCTAssertNotNil(FaviconService.sanitizedIconData(from: try png(
            width: 512, height: 512, backgroundAlpha: 0, drawsMark: true
        )))
    }

    func testDiscoversDeclaredIconsAndManifestWithoutReadingScriptOrComments() throws {
        let page = URL(string: "https://example.com/")!
        let html = Data("""
        <head>
        <!-- <link rel="icon" href="/comment.png"> -->
        <script>const x = '<link rel="icon" href="/script.png">';</script>
        <base href="/assets/">
        <LINK SIZES='512x512' HREF='icon.png?v=1&amp;b=2' REL='shortcut icon'>
        <link href=/app.webmanifest rel=manifest>
        <link rel="apple-touch-icon" href="https://cdn.example.com/touch.png" sizes="192x192">
        <link rel=icon href="http://example.com/insecure.png">
        <link rel=icon href="https://user:secret@example.com/private.png">
        </head>
        """.utf8)
        let result = FaviconDiscovery.html(html, at: page)
        XCTAssertEqual(result.icons.map(\.url.absoluteString), [
            "https://example.com/assets/icon.png?v=1&b=2", "https://cdn.example.com/touch.png"
        ])
        XCTAssertEqual(result.manifest?.absoluteString, "https://example.com/app.webmanifest")
        XCTAssertEqual(result.icons.first?.declaredSize, 512)
        XCTAssertEqual(result.icons.map(\.source), [.htmlIcon, .appleTouchIcon])
    }

    func testManifestResolvesRelativeURLsAndSkipsMonochromeAndUnsafeImages() {
        let data = Data(#"{"icons":[{"src":"../icon.png","sizes":"192x192 512x512"},{"src":"mask.png","purpose":"maskable"},{"src":"mono.png","purpose":"monochrome"},{"src":"data:image/png;base64,abc"},{"src":"http://example.com/icon.png"}]}"#.utf8)
        let icons = FaviconDiscovery.manifest(data, at: URL(string: "https://example.com/app/manifest.json")!)
        XCTAssertEqual(icons.map(\.url.absoluteString), ["https://example.com/icon.png", "https://example.com/app/mask.png"])
        XCTAssertEqual(icons.first?.declaredSize, 512)
        XCTAssertEqual(icons.map(\.source), [.manifestAny, .manifestMaskable])
    }

    func testSameSiteHostAllowsCanonicalAndAssetSubdomainsOnly() {
        XCTAssertTrue(FaviconDiscovery.sameSiteHost("www.example.com", "example.com"))
        XCTAssertTrue(FaviconDiscovery.sameSiteHost("assets.leetcode.com", "leetcode.com"))
        XCTAssertFalse(FaviconDiscovery.sameSiteHost("leetcode.com.evil.test", "leetcode.com"))
        XCTAssertFalse(FaviconDiscovery.sameSiteHost("notleetcode.com", "leetcode.com"))
        XCTAssertFalse(FaviconDiscovery.sameSiteHost("example.net", "example.com"))
    }

    func testRanksDeduplicatesAndBoundsCandidates() {
        let candidates = (0..<20).map { index in
            FaviconDiscovery.Candidate(url: URL(string: "https://example.com/\(index % 10).png")!, declaredSize: index * 32)
        }
        let result = FaviconDiscovery.ranked(candidates)
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(Set(result.map(\.url)).count, 8)
        XCTAssertEqual(result.first?.declaredSize, 19 * 32)
    }

    func testFetchComparesActualSizesAcrossHTMLManifestAndFallbacks() async throws {
        let small = try png(width: 16, height: 16)
        let medium = try png(width: 192, height: 192)
        let large = try png(width: 512, height: 512)
        let service = FaviconService { url, kind, _ in
            let data: Data
            switch url.path {
            case "/":
                XCTAssertEqual(kind, .page)
                XCTAssertNil(url.query)
                data = Data(#"<link rel="icon" sizes="1024x1024" href="/tiny.png"><link rel="apple-touch-icon" href="/medium.png"><link rel="manifest" href="/app/manifest.json">"#.utf8)
            case "/app/manifest.json":
                XCTAssertEqual(kind, .manifest)
                data = Data(#"{"icons":[{"src":"large.png","sizes":"512x512"}]}"#.utf8)
            case "/tiny.png": data = small
            case "/medium.png": data = medium
            case "/app/large.png": data = large
            case "/apple-touch-icon.png": data = medium
            default: return nil
            }
            return .init(data: data, url: url)
        }
        let fetched = await service.fetch(for: URL(string: "https://example.com/private?token=secret")!)
        let result = try XCTUnwrap(fetched)
        XCTAssertEqual(try dimensions(of: result).width, 512)
    }

    func testUnavailablePageStillFindsFallbackAndTinyIconsReturnNil() async throws {
        let large = try png(width: 256, height: 256)
        let service = FaviconService { url, _, _ in
            url.path == "/favicon.ico" ? .init(data: large, url: url) : nil
        }
        let fetched = await service.fetch(for: URL(string: "https://example.com")!)
        XCTAssertNotNil(fetched)
        let tiny = try png(width: 32, height: 32)
        let tinyService = FaviconService { url, kind, _ in
            kind == .image ? .init(data: tiny, url: url) : nil
        }
        let rejected = await tinyService.fetch(for: URL(string: "https://example.com")!)
        XCTAssertNil(rejected)
    }

    func testRootFallbackIsReservedWhenMetadataHasTooManyBrokenCandidates() async throws {
        let icon = try png(width: 256, height: 256)
        let links = (0..<12).map {
            #"<link rel="icon" sizes="512x512" href="/broken\#($0).png">"#
        }.joined()
        let service = FaviconService { url, kind, _ in
            if kind == .page { return .init(data: Data(links.utf8), url: url) }
            if url.path == "/apple-touch-icon.png" { return .init(data: icon, url: url) }
            return nil
        }
        let fetched = await service.fetch(for: URL(string: "https://example.com")!)
        XCTAssertNotNil(fetched)
    }

    func testCanonicalWWWPageRedirectDrivesFallbackURLs() async throws {
        let icon = try png(width: 256, height: 256)
        let service = FaviconService { url, kind, _ in
            if kind == .page {
                return .init(data: Data("<head></head>".utf8), url: URL(string: "https://www.example.com/")!)
            }
            if url.host == "www.example.com", url.path == "/apple-touch-icon.png" {
                return .init(data: icon, url: url)
            }
            return nil
        }
        let fetched = await service.fetch(for: URL(string: "https://example.com/private")!)
        XCTAssertNotNil(fetched)
    }

    func testCancellationNeverReturnsAnIcon() async throws {
        let large = try png(width: 512, height: 512)
        let service = FaviconService { url, _, _ in
            try? await Task.sleep(for: .milliseconds(100))
            return .init(data: large, url: url)
        }
        let task = Task { await service.fetch(for: URL(string: "https://example.com")!) }
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
    }

    func testCatalogArtworkIsSharpAndHostMatchingIsExact() throws {
        for service in CatalogService.all {
            let url = try XCTUnwrap(URL(string: service.address))
            let data = try XCTUnwrap(CatalogIcon.data(for: url), service.name)
            XCTAssertEqual(FaviconService.pixelSize(of: data), 512, service.name)
        }
        XCTAssertNil(CatalogIcon.assetName(for: URL(string: "https://instagram.com.evil.example")))
        XCTAssertNil(CatalogIcon.assetName(for: URL(string: "https://other.google.com")))
        XCTAssertNil(CatalogIcon.assetName(for: URL(string: "https://instagram.com:444")))
        XCTAssertNil(CatalogIcon.assetName(for: URL(string: "http://instagram.com")))
    }

    func testRejectsInvalidAndOversizedInput() {
        XCTAssertNil(FaviconService.sanitizedIconData(from: Data()))
        XCTAssertNil(FaviconService.sanitizedIconData(from: Data("<html>Not an icon</html>".utf8)))
        XCTAssertNil(FaviconService.sanitizedIconData(from: Data(repeating: 0, count: 1_048_577)))
    }

    private func png(
        width: Int,
        height: Int,
        backgroundAlpha: CGFloat = 1,
        drawsMark: Bool = true
    ) throws -> Data {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: backgroundAlpha))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        if drawsMark {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(
                x: CGFloat(width) * 0.28,
                y: CGFloat(height) * 0.28,
                width: CGFloat(width) * 0.44,
                height: CGFloat(height) * 0.44
            ))
        }
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func dimensions(of data: Data) throws -> (width: Int, height: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (
            try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int),
            try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int)
        )
    }

    /// ICO directory entries wrap independently encoded PNG representations.
    private func iconContainer(images: [(size: Int, data: Data)]) -> Data {
        var output = Data([0, 0, 1, 0])
        appendLittleEndian(UInt32(images.count), bytes: 2, to: &output)
        var offset = 6 + 16 * images.count
        for image in images {
            output.append(contentsOf: [UInt8(image.size == 256 ? 0 : image.size),
                                       UInt8(image.size == 256 ? 0 : image.size), 0, 0])
            appendLittleEndian(1, bytes: 2, to: &output)
            appendLittleEndian(32, bytes: 2, to: &output)
            appendLittleEndian(UInt32(image.data.count), bytes: 4, to: &output)
            appendLittleEndian(UInt32(offset), bytes: 4, to: &output)
            offset += image.data.count
        }
        for image in images { output.append(image.data) }
        return output
    }

    private func appendLittleEndian(_ value: UInt32, bytes: Int, to data: inout Data) {
        for index in 0..<bytes {
            data.append(UInt8(truncatingIfNeeded: value >> (8 * index)))
        }
    }
}
