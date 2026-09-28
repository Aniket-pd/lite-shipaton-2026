import SwiftUI
import UIKit

struct BrowserPagePalette {
    let background: UIColor
    let colorScheme: ColorScheme

    init(pageColor: UIColor?, websiteColorScheme: ColorScheme) {
        let traits = UITraitCollection(userInterfaceStyle: websiteColorScheme == .dark ? .dark : .light)
        let fallback = UIColor.systemBackground.resolvedColor(with: traits)
        let color = (pageColor ?? fallback).resolvedColor(with: traits)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        var baseRed: CGFloat = 0, baseGreen: CGFloat = 0, baseBlue: CGFloat = 0, baseAlpha: CGFloat = 0
        fallback.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: &baseAlpha)
        if !color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            red = baseRed; green = baseGreen; blue = baseBlue; alpha = 1
        }
        red = red * alpha + baseRed * (1 - alpha)
        green = green * alpha + baseGreen * (1 - alpha)
        blue = blue * alpha + baseBlue * (1 - alpha)
        background = UIColor(red: red, green: green, blue: blue, alpha: 1)
        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        colorScheme = luminance < 0.179 ? .dark : .light
    }
}
