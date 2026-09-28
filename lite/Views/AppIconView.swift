import SwiftUI
import UIKit

enum IconPalette {
    static func color(_ name: String) -> Color {
        switch name {
        case "teal": .teal
        case "green": .green
        case "orange": .orange
        case "red": .red
        case "pink": .pink
        case "purple": .purple
        case "graphite": Color(.systemGray)
        default: .blue
        }
    }

    static func foregroundColor(_ name: String) -> Color {
        // Bright badge fills need a dark initial/checkmark in both appearances.
        switch name {
        case "teal", "green", "orange", "red", "pink", "graphite": .black
        default: .white
        }
    }
}

struct AppIconView: View {
    var data: Data? = nil
    var websiteURL: URL? = nil
    var symbol: String = "globe"
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(Color(.secondarySystemBackground))
            if data != nil, let asset = CatalogIcon.assetName(for: websiteURL) {
                Image(asset).resizable().interpolation(.high).scaledToFill()
            } else if let data, let image = AppIconImageCache.image(for: data) {
                Image(uiImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.23))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: max(0.5, size / 80))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var fallback: some View {
        if UIImage(systemName: symbol) != nil {
            Image(systemName: symbol)
                .font(.system(size: size * 0.43, weight: .medium))
                .foregroundStyle(.primary)
        } else if let initial = websiteURL?.host?.first {
            Text(String(initial).uppercased())
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "globe")
                .font(.system(size: size * 0.43, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}

struct ProfileBadgedAppIconView: View {
    var data: Data? = nil
    var websiteURL: URL? = nil
    var symbol: String = "globe"
    var color: String = "blue"
    var badgeColor: String? = nil
    var size: CGFloat = 64
    let profileName: String

    var body: some View {
        AppIconView(
            data: data,
            websiteURL: websiteURL,
            symbol: symbol,
            size: size
        )
        .overlay(alignment: .bottomTrailing) {
            ProfileBadgeView(
                label: profileName,
                color: badgeColor ?? color,
                size: max(18, size * 0.3)
            )
            .offset(x: size * 0.06, y: size * 0.06)
        }
    }
}

struct ProfileBadgeView: View {
    let label: String
    var color: String = "blue"
    var size: CGFloat = 22
    var showsFullLabel = false

    private var displayedLabel: String {
        if showsFullLabel { return label }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        badgeContent
            .background { badgeBackground }
            .overlay {
                Circle().strokeBorder(badgeBorder, lineWidth: 1)
            }
    }

    @ViewBuilder private var badgeBackground: some View {
        if showsFullLabel {
            Circle().fill(Color(.secondarySystemBackground))
        } else {
            Circle()
                .fill(Color(.systemBackground))
                .overlay {
                    Circle().fill(badgeTint.opacity(0.16))
                }
        }
    }

    private var badgeTint: Color {
        color == "graphite" ? Color(.label) : IconPalette.color(color)
    }

    private var badgeBorder: Color {
        showsFullLabel ? Color.primary.opacity(0.14) : badgeTint.opacity(0.2)
    }

    private var badgeContent: some View {
        Text(displayedLabel)
            .font(.system(
                size: showsFullLabel ? size * 0.36 : size * 0.42,
                weight: .bold,
                design: .rounded
            ))
            .foregroundStyle(showsFullLabel ? Color.primary : badgeTint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

@MainActor
private enum AppIconImageCache {
    private final class Entry {
        let image: UIImage?
        init(image: UIImage?) { self.image = image }
    }

    private static let cache: NSCache<NSData, Entry> = {
        let cache = NSCache<NSData, Entry>()
        cache.countLimit = 80
        cache.totalCostLimit = 16 * 1_024 * 1_024
        return cache
    }()

    static func image(for data: Data) -> UIImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) { return cached.image }
        let image = FaviconService.isVisuallyUsableIconData(data) ? UIImage(data: data) : nil
        cache.setObject(Entry(image: image), forKey: key, cost: data.count)
        return image
    }
}
