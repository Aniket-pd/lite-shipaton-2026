// Run from the repository root: swift Tools/GenerateAppIcon.swift
import CoreGraphics
import Foundation
import ImageIO

let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("lite/Assets.xcassets/AppIcon.appiconset")

func makeIcon(name: String, background: CGColor, foreground: CGColor) throws {
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
        bytesPerRow: 4096, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    for (x, y) in [(235.0, 235.0), (541.0, 235.0), (235.0, 541.0)] {
        context.setFillColor(foreground)
        context.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: 248, height: 248), cornerWidth: 56, cornerHeight: 56, transform: nil))
        context.fillPath()
    }
    context.setStrokeColor(foreground.copy(alpha: 0.65)!)
    context.addPath(CGPath(roundedRect: CGRect(x: 553, y: 553, width: 224, height: 224), cornerWidth: 44, cornerHeight: 44, transform: nil))
    context.setLineWidth(24)
    context.strokePath()
    let output = CGImageDestinationCreateWithURL(destination.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(output, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(output) else { throw CocoaError(.fileWriteUnknown) }
}

try makeIcon(name: "AppIcon.png", background: CGColor(srgbRed: 0.04, green: 0.39, blue: 0.91, alpha: 1), foreground: CGColor(gray: 1, alpha: 1))
try makeIcon(name: "AppIcon-dark.png", background: CGColor(srgbRed: 0.075, green: 0.095, blue: 0.14, alpha: 1), foreground: CGColor(srgbRed: 0.45, green: 0.68, blue: 1, alpha: 1))
try makeIcon(name: "AppIcon-tinted.png", background: CGColor(gray: 0, alpha: 1), foreground: CGColor(gray: 1, alpha: 1))
