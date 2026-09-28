import SwiftUI

enum SavedSortOrder: String, CaseIterable, Identifiable {
    case newest, name

    var id: String { rawValue }
    var title: String { self == .newest ? "Newest First" : "Name A–Z" }
}

struct SavedSectionPicker: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var selection: SavedSection

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 28))
        layout {
            ForEach(SavedSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(selection == section ? Color.primary : Color.secondary)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44, alignment: .leading)
                        .overlay(alignment: .bottomLeading) {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 24, height: 3)
                                .opacity(selection == section ? 1 : 0)
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
                .accessibilityIdentifier("saved.kind.\(section.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Saved Content")
        .accessibilityIdentifier("saved.kind")
    }
}

/// An always-visible field that doesn't reserve a navigation-title row.
struct SavedSearchField: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var text: String
    let prompt: String
    let isActive: Bool
    let focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Color(.secondaryLabel)))
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(focus)
                .onSubmit { focus.wrappedValue = false }
                .accessibilityLabel(prompt)
                .accessibilityIdentifier("saved.search")
                .padding(.vertical, 15)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("saved.search.clear")
                .padding(.trailing, -10)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(SavedGlassSurface(shape: Capsule()))
        .onChange(of: isActive) {
            if !isActive { focus.wrappedValue = false }
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { focus.wrappedValue = false }
        }
    }
}

struct SavedSortMenu: View {
    @Binding var selection: SavedSortOrder

    var body: some View {
        Menu {
            SavedSortOptions(selection: $selection)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort: \(selection.title)")
        .accessibilityIdentifier("saved.sort")
    }
}

struct SavedSortOptions: View {
    @Binding var selection: SavedSortOrder

    var body: some View {
        Picker("Sort Saved Items", selection: $selection) {
            ForEach(SavedSortOrder.allCases) { order in
                Text(order.title)
                    .tag(order)
                    .accessibilityIdentifier("saved.sort.\(order.rawValue)")
            }
        }
    }
}

struct SavedGlassSurface<SurfaceShape: InsettableShape>: ViewModifier {
    let shape: SurfaceShape
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content.background(Color(.secondarySystemGroupedBackground), in: shape)
            } else if #available(iOS 26, *) {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.background(.ultraThinMaterial, in: shape)
            }
        }
        .overlay {
            if contrast == .increased {
                shape.strokeBorder(.primary.opacity(0.45), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct SavedGlassContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) { content }
        } else {
            content
        }
    }
}
