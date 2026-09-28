import SwiftUI

/// Each group owns a native horizontal scroll view. Artwork stays front-facing
/// and scales; labels and hit targets keep their normal geometry as the rail scrolls.
struct AppGroupCard: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var tileWidth = 98.0
    @ScaledMetric(relativeTo: .footnote) private var iconSize = 80.0
    @ScaledMetric(relativeTo: .footnote) private var nameHeight = 36.0

    let collection: LiteAppCollection
    @Binding var focusedAppID: UUID?
    let openApp: (LiteApp) -> Void
    let showAll: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    private var apps: [LiteApp] { collection.orderedApps }
    var body: some View {
        VStack(spacing: 4) {
            header

            if apps.isEmpty {
                emptyState
            } else if typeSize.isAccessibilitySize {
                accessibleApps
            } else {
                carousel
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
        .groupCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groups.card.\(collection.name)")
        .onChange(of: apps.map(\.id), initial: true) { oldIDs, ids in
            // Editing membership must never leave the rail pointing at a removed app.
            if focusedAppID == nil || !ids.contains(where: { $0 == focusedAppID }) {
                // Start among the first few apps, with neighbours on both sides.
                // Membership changes instead recover to the beginning of the group.
                let initialIndex = min(2, ids.count / 2)
                focusedAppID = oldIDs == ids ? ids.dropFirst(initialIndex).first : ids.first
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: showAll) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        groupName
                        appCount
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 3) {
                        groupName
                        appCount
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(collection.name), \(apps.count) \(apps.count == 1 ? "app" : "apps")")
            .accessibilityHint("Shows all apps in this group")
            .accessibilityIdentifier("groups.group.\(collection.name)")

            Menu {
                Button("See All Apps", systemImage: "list.bullet", action: showAll)
                Button("Edit Group", systemImage: "pencil", action: edit)
                Divider()
                Button("Delete Group", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .tint(.primary)
            .accessibilityLabel("Options for \(collection.name)")
            .accessibilityIdentifier("groups.menu.\(collection.name)")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
    }

    private var groupName: some View {
        Text(collection.name)
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    private var appCount: some View {
        Text("\(apps.count) \(apps.count == 1 ? "app" : "apps")")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private var carousel: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 4) {
                    ForEach(apps) { app in
                        AppGroupCarouselItem(
                            app: app,
                            isFocused: app.id == focusedAppID,
                            iconSize: iconSize,
                            tileWidth: tileWidth,
                            nameHeight: nameHeight,
                            viewportWidth: geometry.size.width,
                            coordinateSpaceID: collection.id,
                            reduceMotion: reduceMotion,
                            increaseContrast: contrast == .increased,
                            open: { openApp(app) }
                        )
                        .id(app.id)
                    }
                }
                .scrollTargetLayout()
            }
            // Symmetric content margins let the first and last items settle at
            // the same center point without a custom drag recognizer or physics.
            .contentMargins(.horizontal, max(0, (geometry.size.width - tileWidth) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $focusedAppID, anchor: .center)
            .sensoryFeedback(.selection, trigger: focusedAppID) { previous, current in
                // Tick once per app, skipping initial positioning and removed members.
                guard let previous, let current, previous != current else { return false }
                return apps.contains { $0.id == previous } && apps.contains { $0.id == current }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .accessibilityIdentifier("groups.carousel.\(collection.name)")
        }
        .frame(height: iconSize + nameHeight + 12)
        .coordinateSpace(.named(collection.id))
    }

    private var accessibleApps: some View {
        VStack(spacing: 4) {
            ForEach(apps) { app in
                Button { openApp(app) } label: {
                    HStack(spacing: 12) {
                        ProfileBadgedAppIconView(
                            data: app.iconData, websiteURL: app.url,
                            symbol: app.iconSymbol, color: app.iconColor, size: 48,
                            profileName: LiteAppGrouping.profileName(for: app)
                        )
                        Text(app.name)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if app.isBiometricLocked {
                            Image(systemName: "lock.fill").font(.body)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(app.name)
                .accessibilityValue(app.isBiometricLocked ? "Locked" : "")
                .accessibilityIdentifier("groups.open.\(app.name)")
            }
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No apps in this group")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add Apps", action: edit)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("groups.addApps.\(collection.name)")
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

}

private struct AppGroupCarouselItem: View {
    let app: LiteApp
    let isFocused: Bool
    let iconSize: CGFloat
    let tileWidth: CGFloat
    let nameHeight: CGFloat
    let viewportWidth: CGFloat
    let coordinateSpaceID: UUID
    let reduceMotion: Bool
    let increaseContrast: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 6) {
                depthIcon

                Text(app.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: tileWidth, height: nameHeight, alignment: .top)
                    .opacity(isFocused ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isFocused)
            }
            .padding(.top, 6)
            .frame(width: tileWidth)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.name)
        .accessibilityValue(app.isBiometricLocked ? "Locked" : "")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .accessibilityIdentifier("groups.open.\(app.name)")
    }

    private var depthIcon: some View {
        decoratedIcon.visualEffect { content, geometry in
            // Measure outside the scroll view's content margins so the visual
            // center and the native snap point use the same coordinate space.
            let center = geometry.frame(in: .named(coordinateSpaceID)).midX
            let distance = (center - viewportWidth / 2) / (tileWidth + 4)
            // Emphasize the centered app while neighbours share a smaller,
            // front-facing size, like a console's profile selection row.
            let depth = min(abs(distance), 1)
            let focus = 1 - depth * depth * (3 - 2 * depth)
            let scale: CGFloat = reduceMotion ? 1 : 0.8 + focus * 0.2
            // Keep every brand mark legible; scale and label carry focus.
            let opacity = increaseContrast ? 1.0 : 0.68 + Double(focus) * 0.32
            return content
                .scaleEffect(scale)
                .opacity(opacity)
        }
    }

    private var decoratedIcon: some View {
        ProfileBadgedAppIconView(
            data: app.iconData, websiteURL: app.url,
            symbol: app.iconSymbol, color: app.iconColor, size: iconSize,
            profileName: LiteAppGrouping.profileName(for: app)
        )
        .shadow(color: .black.opacity(0.24), radius: 10, y: 6)
        .overlay(alignment: .bottomLeading) {
            if app.isBiometricLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .shadow(color: Color(.systemBackground).opacity(0.9), radius: 1)
                    .offset(x: -3, y: 3)
            }
        }
    }
}
