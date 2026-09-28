import SwiftUI
import WidgetKit

private struct WidgetLiteApp: Codable, Identifiable {
    let id: UUID
    let name: String
    let iconData: Data?
    let iconSymbol: String
    let iconColor: String
}

private struct FavoritesEntry: TimelineEntry {
    let date: Date
    let apps: [WidgetLiteApp]
}

private struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesEntry {
        FavoritesEntry(date: .now, apps: [
            WidgetLiteApp(id: UUID(), name: "Lite App", iconData: nil, iconSymbol: "globe", iconColor: "blue")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
        completion(FavoritesEntry(date: .now, apps: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
        completion(Timeline(entries: [FavoritesEntry(date: .now, apps: load())], policy: .never))
    }

    private func load() -> [WidgetLiteApp] {
        guard let defaults = UserDefaults(suiteName: "group.aniket.lite"),
              let data = defaults.data(forKey: "launchMetadata.widget.v2") else { return [] }
        return (try? JSONDecoder().decode([WidgetLiteApp].self, from: data)) ?? []
    }
}

private struct LiteFavoritesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FavoritesEntry

    private var maximumCount: Int {
        switch family {
        case .systemSmall: 1
        case .systemMedium: 3
        default: 6
        }
    }

    var body: some View {
        if entry.apps.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "star")
                    .font(.title2)
                Text("Choose apps in Lite’s library settings")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.background, for: .widget)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: family == .systemSmall ? 1 : 3), spacing: 16) {
                ForEach(Array(entry.apps.prefix(maximumCount))) { app in
                    Link(destination: URL(string: "lite://open/\(app.id.uuidString)")!) {
                        VStack(spacing: 7) {
                            WidgetAppIcon(app: app)
                            Text(app.name)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("Open \(app.name) in Lite")
                }
            }
            .containerBackground(.background, for: .widget)
            .widgetURL(family == .systemSmall ? entry.apps.first.flatMap { URL(string: "lite://open/\($0.id.uuidString)") } : nil)
        }
    }
}

private struct WidgetAppIcon: View {
    let app: WidgetLiteApp

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(.secondarySystemBackground))
            if let image = decodedImage {
                Image(uiImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: UIImage(systemName: app.iconSymbol) == nil ? "globe" : app.iconSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 44, height: 44)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
    }

    private var decodedImage: UIImage? {
        guard let data = app.iconData, let image = UIImage(data: data),
              min(image.size.width, image.size.height) * image.scale >= 128 else { return nil }
        return image
    }
}

struct LiteFavoritesWidget: Widget {
    let kind = "LiteFavoritesWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
            LiteFavoritesWidgetView(entry: entry)
        }
        .configurationDisplayName("Lite Shortcuts")
        .description("Open selected website profiles directly inside Lite.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct LiteWidgetBundle: WidgetBundle {
    var body: some Widget { LiteFavoritesWidget() }
}
