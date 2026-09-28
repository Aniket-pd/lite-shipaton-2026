import SwiftUI

struct ProfileAppearanceSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        }
    }
}

/// The source and symbol never change the profile's badge color.
struct ProfileIconPicker: View {
    @Binding var useWebsiteIcon: Bool
    @Binding var symbol: String
    let iconData: Data?
    let websiteURL: URL?
    let websiteName: String
    var isFetchingIcon = false
    var identifierPrefix = "creation"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("App icon", selection: $useWebsiteIcon) {
                Text("Website").tag(true)
                Text("Custom").tag(false)
            }
            .pickerStyle(.segmented)
            .disabled(isFetchingIcon || iconData == nil)
            .accessibilityIdentifier("\(identifierPrefix).iconSource")

            if isFetchingIcon {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Finding website icon…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if useWebsiteIcon, let iconData {
                HStack(spacing: 14) {
                    AppIconView(data: iconData, websiteURL: websiteURL, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Website icon").font(.subheadline.weight(.semibold))
                        Text("Original icon from \(websiteName).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(4)
            } else {
                if iconData == nil {
                    Text("No website icon available. Choose a symbol.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ProfileSymbolPicker(symbol: $symbol, identifierPrefix: identifierPrefix)
            }
        }
    }
}

private struct ProfileSymbolPicker: View {
    @Environment(ProStore.self) private var pro
    @State private var showPro = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var symbol: String
    let identifierPrefix: String
    private let symbols = ["globe", "star", "heart", "briefcase", "person.crop.circle", "envelope", "play.rectangle", "bag"]

    // Keep an existing service-specific symbol selectable when switching modes.
    private var availableSymbols: [String] {
        let all = symbols + ProCatalog.symbols
        return all.contains(symbol) ? all : all + [symbol]
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                count: dynamicTypeSize.isAccessibilitySize ? 3 : 4), spacing: 8) {
            ForEach(availableSymbols, id: \.self) { item in
                Button {
                    if ProCatalog.symbols.contains(item) && !pro.isPro && item != symbol { showPro = true }
                    else { symbol = item }
                } label: {
                    Image(systemName: item)
                        .font(.title2)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(symbol == item ? Color(.tertiarySystemFill) : .clear,
                                    in: .rect(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            if ProCatalog.symbols.contains(item) && !pro.isPro && symbol != item {
                                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary).padding(4)
                            } else if symbol == item {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white, Color.accentColor)
                                    .padding(4)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(iconLabel(item))
                .accessibilityAddTraits(symbol == item ? [.isSelected] : [])
                .accessibilityIdentifier("\(identifierPrefix).icon.\(item)")
            }
        }
        .sheet(isPresented: $showPro) { ProPaywallView(feature: .customization) }
    }

    private func iconLabel(_ symbol: String) -> String {
        switch symbol {
        case "person.crop.circle": "Person icon"
        case "play.rectangle": "Video icon"
        case "text.bubble": "Speech bubble icon"
        case "bubble.left.and.bubble.right": "Conversation icon"
        case "person.2": "People icon"
        default: "\(symbol.capitalized) icon"
        }
    }
}

struct BadgeColorPicker: View {
    @Environment(ProStore.self) private var pro
    @State private var showPro = false
    @Binding var color: String
    var identifierPrefix = "creation"
    private let colors = ["blue", "teal", "green", "orange", "pink", "graphite"]

    private var availableColors: [String] {
        let all = colors + ProCatalog.colors
        return all.contains(color) ? all : all + [color]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { swatches }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 8) {
                swatches
            }
        }
        .sheet(isPresented: $showPro) { ProPaywallView(feature: .customization) }
    }

    private var swatches: some View {
        ForEach(availableColors, id: \.self) { item in
            Button {
                if ProCatalog.colors.contains(item) && !pro.isPro && item != color { showPro = true }
                else { color = item }
            } label: {
                Circle()
                    .fill(IconPalette.color(item))
                    .frame(width: 30, height: 30)
                    .overlay {
                        if ProCatalog.colors.contains(item) && !pro.isPro && color != item {
                            Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.white)
                        } else if color == item {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(IconPalette.foregroundColor(item))
                        }
                    }
                    .padding(3)
                    .overlay {
                        Circle().strokeBorder(color == item ? Color.primary : .clear, lineWidth: 2)
                    }
                    .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.capitalized) badge")
            .accessibilityAddTraits(color == item ? [.isSelected] : [])
            .accessibilityIdentifier("\(identifierPrefix).badgeColor.\(item)")
        }
    }
}
