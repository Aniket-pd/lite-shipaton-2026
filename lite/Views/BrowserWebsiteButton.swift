import SwiftUI

struct BrowserWebsiteButton: View {
    let appName: String
    let host: String
    var isCollapsed = false
    var labelWidth: CGFloat?
    var textScale: CGFloat = 1
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            Text(host)
                .font(.subheadline.weight(.medium))
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.middle)
                .frame(width: labelWidth)
                .scaleEffect(textScale)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(isCollapsed ? "\(host). Show browser controls" : "\(appName), \(host). Website information")
        .accessibilityIdentifier(isCollapsed ? "browser.expand" : "browser.websiteInfo")
    }
}
