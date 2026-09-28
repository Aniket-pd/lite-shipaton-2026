import SwiftUI

private struct BrowserWebsiteColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

extension EnvironmentValues {
    /// Captured outside the browser presentation. Chrome may follow the page's
    /// background without changing the website's prefers-color-scheme setting.
    var browserWebsiteColorScheme: ColorScheme {
        get { self[BrowserWebsiteColorSchemeKey.self] }
        set { self[BrowserWebsiteColorSchemeKey.self] = newValue }
    }
}
